//! SQLCipher 4.x Encrypted Database Storage Layer (Unified Topic + Secret Text Schema)
//!
//! Combines Full-Database Page-Level Encryption (SQLCipher AES-256-CBC + HMAC-SHA512)
//! with Per-Record Field-Level AES-256-GCM AEAD (`encrypted_payload`) bound to deterministic AAD.

use crate::crypto::{decrypt_field_aead, encrypt_field_aead, CryptoError, DataEncryptionKey};
use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};
use thiserror::Error;
use zeroize::Zeroizing;

pub const CURRENT_SCHEMA_VERSION: u16 = 1;

#[derive(Debug, Error)]
pub enum VaultDbError {
    #[error("SQLCipher database error: {0}")]
    SqlError(#[from] rusqlite::Error),
    #[error("Cryptographic operation failed: {0}")]
    Crypto(#[from] CryptoError),
    #[error("Vault topic not found")]
    NotFound,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VaultTopicRecord {
    pub item_uuid: String,
    pub topic: String,
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
            updated_at_unix INTEGER NOT NULL,
            schema_version INTEGER NOT NULL DEFAULT 1,
            encrypted_payload BLOB NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_vault_topics_updated ON vault_topics(updated_at_unix DESC);",
    )?;

    Ok(conn)
}


/// Inserts or updates a vault topic record, encrypting `secret_text_bytes` with AES-256-GCM + Record AAD.
pub fn upsert_vault_topic(
    conn: &Connection,
    dek: &DataEncryptionKey,
    meta: &VaultTopicRecord,
    secret_text_bytes: &[u8],
) -> Result<(), VaultDbError> {
    let aad = build_record_aad(&meta.item_uuid, meta.schema_version);
    let encrypted_blob = encrypt_field_aead(dek, secret_text_bytes, &aad)?;

    conn.execute(
        "INSERT INTO vault_topics (
            item_uuid, topic, updated_at_unix, schema_version, encrypted_payload
        ) VALUES (?1, ?2, ?3, ?4, ?5)
        ON CONFLICT(item_uuid) DO UPDATE SET
            topic = excluded.topic,
            updated_at_unix = excluded.updated_at_unix,
            schema_version = excluded.schema_version,
            encrypted_payload = excluded.encrypted_payload;",
        params![
            meta.item_uuid,
            meta.topic,
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
        "SELECT item_uuid, topic, updated_at_unix, schema_version
         FROM vault_topics
         ORDER BY updated_at_unix DESC",
    )?;

    let rows = stmt.query_map([], |row| {
        Ok(VaultTopicRecord {
            item_uuid: row.get(0)?,
            topic: row.get(1)?,
            updated_at_unix: row.get(2)?,
            schema_version: row.get(3)?,
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
    let mut stmt = conn.prepare(
        "SELECT schema_version, encrypted_payload
         FROM vault_topics
         WHERE item_uuid = ?1",
    )?;

    let (schema_version, encrypted_blob): (u16, Vec<u8>) = stmt
        .query_row(params![item_uuid], |row| Ok((row.get(0)?, row.get(1)?)))
        .map_err(|_| VaultDbError::NotFound)?;

    let aad = build_record_aad(item_uuid, schema_version);
    let decrypted = decrypt_field_aead(dek, &encrypted_blob, &aad)?;
    Ok(decrypted)
}


