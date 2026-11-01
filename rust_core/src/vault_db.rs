//! SQLCipher 4.x Encrypted Database Storage Layer (Unified Topic + Secret Text Schema)
//!
//! Combines Full-Database Page-Level Encryption (SQLCipher AES-256-CBC + HMAC-SHA512)
//! with Per-Record Field-Level AES-256-GCM AEAD (`encrypted_payload`) bound to deterministic AAD.

use crate::crypto::{
    build_item_lock_aad, decrypt_field_aead, decrypt_item_inner_layer, encrypt_field_aead,
    encrypt_item_inner_layer, generate_item_lock_salt, CryptoError, DataEncryptionKey, SALT_LEN,
};
use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};
use thiserror::Error;
use zeroize::Zeroizing;

pub const CURRENT_SCHEMA_VERSION: u16 = 2;

#[derive(Debug, Error)]
pub enum VaultDbError {
    #[error("SQLCipher database error: {0}")]
    SqlError(#[from] rusqlite::Error),
    #[error("Cryptographic operation failed: {0}")]
    Crypto(#[from] CryptoError),
    #[error("Vault topic not found")]
    NotFound,
    #[error("Item is locked. Password hint: {0}")]
    ItemLocked(String),
    #[error("System clock error: {0}")]
    Clock(#[from] std::time::SystemTimeError),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VaultTopicRecord {
    pub item_uuid: String,
    pub topic: String,
    #[serde(default)]
    pub has_extra_lock: bool,
    #[serde(default)]
    pub item_lock_salt: Option<Vec<u8>>,
    #[serde(default)]
    pub password_hint: String,
    pub updated_at_unix: i64,
    pub schema_version: u16,
}

/// Builds the deterministic AAD (Associated Authenticated Data) binding for a vault topic record.
/// Prevents an attacker with root access from swapping `encrypted_payload` blobs between rows.
pub fn build_record_aad(item_uuid: &str, schema_version: u16) -> Vec<u8> {
    format!("superxsecret.v1.topic:{}|v{}", item_uuid, schema_version).into_bytes()
}

/// Opens an encrypted SQLCipher 4.x connection using the HKDF-derived 256-bit raw page key
/// and enforces strict memory security pragmas.
pub fn open_sqlcipher_connection(
    db_path: &str,
    dek: &DataEncryptionKey,
) -> Result<Connection, VaultDbError> {
    let conn = Connection::open(db_path)?;
    let raw_hex_key = dek.derive_sqlcipher_raw_key()?;

    conn.pragma_update(None, "key", raw_hex_key.as_str())?;
    conn.pragma_update(None, "cipher_page_size", 4096)?;
    conn.pragma_update(None, "cipher_memory_security", "ON")?;
    conn.pragma_update(None, "foreign_keys", "ON")?;
    conn.pragma_update(None, "secure_delete", "ON")?;

    conn.execute_batch(
        "CREATE TABLE IF NOT EXISTS vault_topics (
            item_uuid TEXT PRIMARY KEY NOT NULL,
            topic TEXT NOT NULL,
            has_extra_lock INTEGER NOT NULL DEFAULT 0,
            item_lock_salt BLOB NULL,
            password_hint TEXT NOT NULL DEFAULT '',
            updated_at_unix INTEGER NOT NULL,
            schema_version INTEGER NOT NULL DEFAULT 2,
            encrypted_payload BLOB NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_vault_topics_updated ON vault_topics(updated_at_unix DESC);",
    )?;

    let columns = {
        let mut stmt = conn.prepare("PRAGMA table_info(vault_topics)")?;
        let columns = stmt.query_map([], |row| row.get::<_, String>(1))?;
        columns.collect::<Result<Vec<_>, _>>()?
    };
    for (column, alter_sql) in [
        (
            "has_extra_lock",
            "ALTER TABLE vault_topics ADD COLUMN has_extra_lock INTEGER NOT NULL DEFAULT 0",
        ),
        (
            "item_lock_salt",
            "ALTER TABLE vault_topics ADD COLUMN item_lock_salt BLOB NULL",
        ),
        (
            "password_hint",
            "ALTER TABLE vault_topics ADD COLUMN password_hint TEXT NOT NULL DEFAULT ''",
        ),
    ] {
        if !columns.iter().any(|existing| existing == column) {
            conn.execute(alter_sql, [])?;
        }
    }

    Ok(conn)
}

/// Inserts or updates a vault topic record, encrypting `secret_text_bytes` with AES-256-GCM + Record AAD.
pub fn upsert_vault_topic(
    conn: &Connection,
    dek: &DataEncryptionKey,
    meta: &VaultTopicRecord,
    secret_text_bytes: &[u8],
) -> Result<(), VaultDbError> {
    upsert_vault_topic_with_item_password(conn, dek, meta, secret_text_bytes, None)
}

pub fn upsert_vault_topic_with_item_password(
    conn: &Connection,
    dek: &DataEncryptionKey,
    meta: &VaultTopicRecord,
    secret_text_bytes: &[u8],
    item_password: Option<&[u8]>,
) -> Result<(), VaultDbError> {
    let aad = build_record_aad(&meta.item_uuid, meta.schema_version);
    let inner_payload = Zeroizing::new(if meta.has_extra_lock {
        let item_password =
            item_password.ok_or_else(|| VaultDbError::ItemLocked(meta.password_hint.clone()))?;
        let salt: [u8; SALT_LEN] = meta
            .item_lock_salt
            .as_deref()
            .ok_or(CryptoError::InvalidLength)?
            .try_into()
            .map_err(|_| CryptoError::InvalidLength)?;
        encrypt_item_inner_layer(
            item_password,
            &salt,
            secret_text_bytes,
            &build_item_lock_aad(&meta.item_uuid, meta.schema_version),
        )?
    } else {
        secret_text_bytes.to_vec()
    });
    let encrypted_blob = encrypt_field_aead(dek, &inner_payload, &aad)?;

    conn.execute(
        "INSERT INTO vault_topics (
            item_uuid, topic, has_extra_lock, item_lock_salt, password_hint,
            updated_at_unix, schema_version, encrypted_payload
        ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)
        ON CONFLICT(item_uuid) DO UPDATE SET
            topic = excluded.topic,
            has_extra_lock = excluded.has_extra_lock,
            item_lock_salt = excluded.item_lock_salt,
            password_hint = excluded.password_hint,
            updated_at_unix = excluded.updated_at_unix,
            schema_version = excluded.schema_version,
            encrypted_payload = excluded.encrypted_payload;",
        params![
            meta.item_uuid,
            meta.topic,
            meta.has_extra_lock,
            meta.item_lock_salt,
            meta.password_hint,
            meta.updated_at_unix,
            meta.schema_version,
            encrypted_blob
        ],
    )?;

    Ok(())
}

/// Lists all non-sensitive topic summaries without decrypting any `encrypted_payload` blobs!
pub fn list_vault_summaries(conn: &Connection) -> Result<Vec<VaultTopicRecord>, VaultDbError> {
    let mut stmt = conn.prepare(
        "SELECT item_uuid, topic, has_extra_lock, item_lock_salt, password_hint,
                updated_at_unix, schema_version
         FROM vault_topics
         ORDER BY updated_at_unix DESC",
    )?;

    let rows = stmt.query_map([], |row| {
        Ok(VaultTopicRecord {
            item_uuid: row.get(0)?,
            topic: row.get(1)?,
            has_extra_lock: row.get(2)?,
            item_lock_salt: row.get(3)?,
            password_hint: row.get(4)?,
            updated_at_unix: row.get(5)?,
            schema_version: row.get(6)?,
        })
    })?;

    let mut items = Vec::new();
    for item in rows {
        items.push(item?);
    }
    Ok(items)
}

/// Just-In-Time (JIT) decryption of a single topic's secret payload when the user taps "View".
pub fn decrypt_single_item_payload(
    conn: &Connection,
    dek: &DataEncryptionKey,
    item_uuid: &str,
) -> Result<Zeroizing<Vec<u8>>, VaultDbError> {
    decrypt_single_item_payload_with_item_password(conn, dek, item_uuid, None)
}

pub fn decrypt_single_item_payload_with_item_password(
    conn: &Connection,
    dek: &DataEncryptionKey,
    item_uuid: &str,
    item_password: Option<&[u8]>,
) -> Result<Zeroizing<Vec<u8>>, VaultDbError> {
    let mut stmt = conn.prepare(
        "SELECT schema_version, encrypted_payload, has_extra_lock, item_lock_salt, password_hint
         FROM vault_topics
         WHERE item_uuid = ?1",
    )?;

    let (schema_version, encrypted_blob, has_extra_lock, item_lock_salt, password_hint): (
        u16,
        Vec<u8>,
        bool,
        Option<Vec<u8>>,
        String,
    ) = stmt
        .query_row(params![item_uuid], |row| {
            Ok((
                row.get(0)?,
                row.get(1)?,
                row.get(2)?,
                row.get(3)?,
                row.get(4)?,
            ))
        })
        .map_err(|_| VaultDbError::NotFound)?;

    let aad = build_record_aad(item_uuid, schema_version);
    let outer_decrypted = decrypt_field_aead(dek, &encrypted_blob, &aad)?;
    if !has_extra_lock {
        return Ok(outer_decrypted);
    }

    let item_password =
        item_password.ok_or_else(|| VaultDbError::ItemLocked(password_hint.clone()))?;
    let salt: [u8; SALT_LEN] = item_lock_salt
        .as_deref()
        .ok_or(CryptoError::InvalidLength)?
        .try_into()
        .map_err(|_| CryptoError::InvalidLength)?;
    decrypt_item_inner_layer(
        item_password,
        &salt,
        &outer_decrypted,
        &build_item_lock_aad(item_uuid, schema_version),
    )
    .map_err(|error| match error {
        CryptoError::AeadFailure => VaultDbError::ItemLocked(password_hint),
        other => VaultDbError::Crypto(other),
    })
}

pub fn set_vault_topic_extra_lock(
    conn: &Connection,
    dek: &DataEncryptionKey,
    item_uuid: &str,
    new_item_password: &[u8],
    password_hint: &str,
    current_item_password: Option<&[u8]>,
) -> Result<(), VaultDbError> {
    let mut record = list_vault_summaries(conn)?
        .into_iter()
        .find(|item| item.item_uuid == item_uuid)
        .ok_or(VaultDbError::NotFound)?;
    let secret = decrypt_single_item_payload_with_item_password(
        conn,
        dek,
        item_uuid,
        current_item_password,
    )?;
    record.has_extra_lock = true;
    record.item_lock_salt = Some(generate_item_lock_salt().to_vec());
    record.password_hint = password_hint.to_string();
    record.updated_at_unix = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)?
        .as_secs() as i64;
    upsert_vault_topic_with_item_password(conn, dek, &record, &secret, Some(new_item_password))
}

pub fn remove_vault_topic_extra_lock(
    conn: &Connection,
    dek: &DataEncryptionKey,
    item_uuid: &str,
    item_password: &[u8],
) -> Result<(), VaultDbError> {
    let mut record = list_vault_summaries(conn)?
        .into_iter()
        .find(|item| item.item_uuid == item_uuid)
        .ok_or(VaultDbError::NotFound)?;
    if !record.has_extra_lock {
        return Ok(());
    }
    let secret =
        decrypt_single_item_payload_with_item_password(conn, dek, item_uuid, Some(item_password))?;
    record.has_extra_lock = false;
    record.item_lock_salt = None;
    record.password_hint.clear();
    record.updated_at_unix = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)?
        .as_secs() as i64;
    upsert_vault_topic_with_item_password(conn, dek, &record, &secret, None)
}

#[cfg(test)]
mod tests {
    use super::{
        decrypt_single_item_payload_with_item_password, open_sqlcipher_connection,
        remove_vault_topic_extra_lock, set_vault_topic_extra_lock, upsert_vault_topic,
        upsert_vault_topic_with_item_password, VaultDbError, VaultTopicRecord,
        CURRENT_SCHEMA_VERSION,
    };
    use crate::crypto::DataEncryptionKey;

    #[test]
    fn extra_locked_record_is_double_encrypted_and_has_persisted_metadata() {
        let dek = DataEncryptionKey::generate_random();
        let conn = open_sqlcipher_connection(":memory:", &dek).unwrap();
        let item = VaultTopicRecord {
            item_uuid: "locked-item-1".to_string(),
            topic: "Private".to_string(),
            has_extra_lock: true,
            item_lock_salt: Some(vec![0xA5; 32]),
            password_hint: "Favorite color".to_string(),
            updated_at_unix: 1,
            schema_version: CURRENT_SCHEMA_VERSION,
        };
        upsert_vault_topic_with_item_password(
            &conn,
            &dek,
            &item,
            b"hidden payload",
            Some(b"separate item password"),
        )
        .unwrap();

        assert!(matches!(
            decrypt_single_item_payload_with_item_password(&conn, &dek, &item.item_uuid, None),
            Err(VaultDbError::ItemLocked(hint)) if hint == item.password_hint
        ));
        assert!(matches!(
            decrypt_single_item_payload_with_item_password(
                &conn,
                &dek,
                &item.item_uuid,
                Some(b"wrong password"),
            ),
            Err(VaultDbError::ItemLocked(_))
        ));
        let plaintext = decrypt_single_item_payload_with_item_password(
            &conn,
            &dek,
            &item.item_uuid,
            Some(b"separate item password"),
        )
        .unwrap();
        assert_eq!(plaintext.as_slice(), b"hidden payload");
    }

    #[test]
    fn extra_lock_can_be_changed_and_removed_without_changing_secret() {
        let dek = DataEncryptionKey::generate_random();
        let conn = open_sqlcipher_connection(":memory:", &dek).unwrap();
        let item = VaultTopicRecord {
            item_uuid: "managed-item".to_string(),
            topic: "Managed".to_string(),
            has_extra_lock: false,
            item_lock_salt: None,
            password_hint: String::new(),
            updated_at_unix: 1,
            schema_version: CURRENT_SCHEMA_VERSION,
        };
        upsert_vault_topic(&conn, &dek, &item, b"private text").unwrap();

        set_vault_topic_extra_lock(
            &conn,
            &dek,
            &item.item_uuid,
            b"first item password",
            "first hint",
            None,
        )
        .unwrap();
        set_vault_topic_extra_lock(
            &conn,
            &dek,
            &item.item_uuid,
            b"second item password",
            "second hint",
            Some(b"first item password"),
        )
        .unwrap();
        let after_change = decrypt_single_item_payload_with_item_password(
            &conn,
            &dek,
            &item.item_uuid,
            Some(b"second item password"),
        )
        .unwrap();
        assert_eq!(after_change.as_slice(), b"private text");

        remove_vault_topic_extra_lock(&conn, &dek, &item.item_uuid, b"second item password")
            .unwrap();
        let after_remove =
            decrypt_single_item_payload_with_item_password(&conn, &dek, &item.item_uuid, None)
                .unwrap();
        assert_eq!(after_remove.as_slice(), b"private text");
    }
}
