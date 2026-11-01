//! High-level FFI Bridge API exposed to Flutter (`flutter_rust_bridge`)
//!
//! Coordinates Dual-Vault Envelope Encryption (Main Vault Slot A + Secondary Vault Slot B),
//! SQLCipher storage for Unified Topic + Secret Text records, `.sxsi` Single-Item Sharing,
//! and `.sxs` Full Encrypted Backup/Restore.

use crate::crypto::{
    build_item_lock_aad, create_wrapped_key_slot, decrypt_item_inner_layer,
    encrypt_item_inner_layer, generate_item_lock_salt, unwrap_key_slot, DataEncryptionKey,
    WrappedKeySlot, SALT_LEN,
};
use crate::sxs_backup::{
    export_single_item_sxsi_bytes, export_to_sxs_bytes, import_from_sxs_bytes,
    import_single_item_sxsi_bytes,
};
use crate::totp::{generate_totp_sha1, TotpSnapshot};
use crate::vault_db::{
    decrypt_single_item_payload_with_item_password, remove_vault_topic_extra_lock,
    set_vault_topic_extra_lock, upsert_vault_topic_with_item_password, VaultDbError,
    VaultTopicRecord,
};
use rusqlite::Connection;
use serde::{Deserialize, Serialize};
use zeroize::Zeroizing;

pub const SLOT_A_AAD: &[u8] = b"superxsecret.v1.header.slot_a";
pub const SLOT_B_AAD: &[u8] = b"superxsecret.v1.header.slot_b";

/// Dual-Slot Vault Header supporting Main Vault (Slot A) and Secondary Vault (Slot B).
/// Both slots are cryptographically indistinguishable random salt/nonce/AES-GCM blobs.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct DualSlotVaultHeader {
    pub version: u16,
    pub slot_a_main: WrappedKeySlot,
    pub slot_b_secondary: WrappedKeySlot,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum UnlockedVaultMode {
    MainVault,
    SecondaryVault,
}

/// Initializes a new Dual-Slot Vault Header with both a Main Password (Slot A)
/// and a Secondary Password (Slot B).
pub fn initialize_dual_slot_vault_header(
    main_password: String,
    secondary_password: String,
) -> Result<String, String> {
    let main_bytes = Zeroizing::new(main_password.into_bytes());
    let secondary_bytes = Zeroizing::new(secondary_password.into_bytes());

    if main_bytes.as_slice() == secondary_bytes.as_slice() {
        return Err("Main Password and Secondary Password must be distinct".to_string());
    }

    let dek_main = DataEncryptionKey::generate_random();
    let dek_secondary = DataEncryptionKey::generate_random();

    let slot_a_main =
        create_wrapped_key_slot(&main_bytes, &dek_main, SLOT_A_AAD).map_err(|e| e.to_string())?;
    let slot_b_secondary = create_wrapped_key_slot(&secondary_bytes, &dek_secondary, SLOT_B_AAD)
        .map_err(|e| e.to_string())?;

    let header = DualSlotVaultHeader {
        version: 1,
        slot_a_main,
        slot_b_secondary,
    };

    serde_json::to_string(&header).map_err(|e| e.to_string())
}

/// Attempts to unlock the Dual-Slot Vault Header using `candidate_password`.
/// Evaluates both Slot A and Slot B so timing remains consistent, returning which
/// vault mode (`MainVault` or `SecondaryVault`) was unlocked.
pub fn verify_and_unlock_dual_slot(
    header_json: String,
    candidate_password: String,
) -> Result<UnlockedVaultMode, String> {
    let header: DualSlotVaultHeader =
        serde_json::from_str(&header_json).map_err(|e| e.to_string())?;
    let password_bytes = Zeroizing::new(candidate_password.into_bytes());

    let main_res = unwrap_key_slot(&password_bytes, &header.slot_a_main, SLOT_A_AAD);
    let secondary_res = unwrap_key_slot(&password_bytes, &header.slot_b_secondary, SLOT_B_AAD);

    match (main_res, secondary_res) {
        (Ok(_dek_a), _) => Ok(UnlockedVaultMode::MainVault),
        (Err(_), Ok(_dek_b)) => Ok(UnlockedVaultMode::SecondaryVault),
        (Err(_), Err(_)) => Err("Invalid Password".to_string()),
    }
}

pub fn encrypt_locked_item_inner_layer(
    item_password: String,
    item_lock_salt: Vec<u8>,
    item_uuid: String,
    schema_version: u16,
    plaintext: Vec<u8>,
) -> Result<Vec<u8>, String> {
    let password = Zeroizing::new(item_password.into_bytes());
    let plaintext = Zeroizing::new(plaintext);
    let salt: [u8; SALT_LEN] = item_lock_salt
        .try_into()
        .map_err(|_| "Item lock salt must be 32 bytes".to_string())?;
    let aad = build_item_lock_aad(&item_uuid, schema_version);

    encrypt_item_inner_layer(&password, &salt, &plaintext, &aad).map_err(|e| e.to_string())
}

pub fn create_item_lock_salt() -> Vec<u8> {
    generate_item_lock_salt().to_vec()
}

pub fn decrypt_locked_item_inner_layer(
    item_password: String,
    item_lock_salt: Vec<u8>,
    item_uuid: String,
    schema_version: u16,
    ciphertext: Vec<u8>,
) -> Result<Zeroizing<Vec<u8>>, String> {
    let password = Zeroizing::new(item_password.into_bytes());
    let salt: [u8; SALT_LEN] = item_lock_salt
        .try_into()
        .map_err(|_| "Item lock salt must be 32 bytes".to_string())?;
    let ciphertext = Zeroizing::new(ciphertext);
    let aad = build_item_lock_aad(&item_uuid, schema_version);

    decrypt_item_inner_layer(&password, &salt, &ciphertext, &aad).map_err(|e| e.to_string())
}

pub fn create_locked_item(
    conn: &Connection,
    dek: &DataEncryptionKey,
    mut record: VaultTopicRecord,
    secret_text: Vec<u8>,
    item_password: String,
) -> Result<(), String> {
    if item_password.len() < 6 {
        return Err("Item Password must be at least 6 characters".to_string());
    }
    let password = Zeroizing::new(item_password.into_bytes());
    let secret = Zeroizing::new(secret_text);
    record.has_extra_lock = true;
    record.item_lock_salt = Some(generate_item_lock_salt().to_vec());
    upsert_vault_topic_with_item_password(conn, dek, &record, &secret, Some(&password))
        .map_err(|error| error.to_string())
}

pub fn unlock_locked_item(
    conn: &Connection,
    dek: &DataEncryptionKey,
    item_uuid: &str,
    item_password: String,
) -> Result<Zeroizing<Vec<u8>>, String> {
    let password = Zeroizing::new(item_password.into_bytes());
    decrypt_single_item_payload_with_item_password(conn, dek, item_uuid, Some(&password))
        .map_err(|error| error.to_string())
}

pub fn set_item_extra_lock(
    conn: &Connection,
    dek: &DataEncryptionKey,
    item_uuid: &str,
    new_item_password: String,
    password_hint: String,
    current_item_password: Option<String>,
) -> Result<(), String> {
    if new_item_password.len() < 6 {
        return Err("Item Password must be at least 6 characters".to_string());
    }
    let new_password = Zeroizing::new(new_item_password.into_bytes());
    let current_password =
        current_item_password.map(|password| Zeroizing::new(password.into_bytes()));
    set_vault_topic_extra_lock(
        conn,
        dek,
        item_uuid,
        &new_password,
        &password_hint,
        current_password
            .as_deref()
            .map(|password| password.as_slice()),
    )
    .map_err(|error: VaultDbError| error.to_string())
}

pub fn remove_item_extra_lock(
    conn: &Connection,
    dek: &DataEncryptionKey,
    item_uuid: &str,
    item_password: String,
) -> Result<(), String> {
    let password = Zeroizing::new(item_password.into_bytes());
    remove_vault_topic_extra_lock(conn, dek, item_uuid, &password)
        .map_err(|error| error.to_string())
}

/// Computes an offline RFC 6238 6-digit TOTP code for a Base32 secret.
pub fn compute_offline_totp(
    base32_secret: String,
    unix_timestamp_secs: u64,
) -> Result<TotpSnapshot, String> {
    let clean_secret = Zeroizing::new(base32_secret);
    generate_totp_sha1(&clean_secret, unix_timestamp_secs, 30, 6).map_err(|e| e.to_string())
}

/// Creates an encrypted `.sxs` (`"SXSV"`) full backup byte array from a JSON snapshot and password.
pub fn create_sxs_encrypted_backup(
    backup_password: String,
    vault_snapshot_json: String,
) -> Result<Vec<u8>, String> {
    let pwd = Zeroizing::new(backup_password.into_bytes());
    let payload = Zeroizing::new(vault_snapshot_json.into_bytes());
    export_to_sxs_bytes(&pwd, &payload).map_err(|e| e.to_string())
}

/// Decrypts and verifies an encrypted `.sxs` (`"SXSV"`) full backup byte array.
pub fn restore_sxs_encrypted_backup(
    backup_password: String,
    sxs_bytes: Vec<u8>,
) -> Result<String, String> {
    let pwd = Zeroizing::new(backup_password.into_bytes());
    let decrypted = import_from_sxs_bytes(&pwd, &sxs_bytes).map_err(|e| e.to_string())?;
    String::from_utf8(decrypted.to_vec()).map_err(|e| e.to_string())
}

/// Creates an encrypted `.sxsi` (`"SXSI"`) single-item share byte array from a Topic+Secret JSON and File Password.
pub fn create_sxsi_item_share(
    file_password: String,
    topic_json: String,
) -> Result<Vec<u8>, String> {
    let pwd = Zeroizing::new(file_password.into_bytes());
    let payload = Zeroizing::new(topic_json.into_bytes());
    export_single_item_sxsi_bytes(&pwd, &payload).map_err(|e| e.to_string())
}

/// Decrypts and verifies an encrypted `.sxsi` (`"SXSI"`) single-item share byte array using the sender's File Password.
pub fn decode_sxsi_item_share(
    file_password: String,
    sxsi_bytes: Vec<u8>,
) -> Result<String, String> {
    let pwd = Zeroizing::new(file_password.into_bytes());
    let decrypted = import_single_item_sxsi_bytes(&pwd, &sxsi_bytes).map_err(|e| e.to_string())?;
    String::from_utf8(decrypted.to_vec()).map_err(|e| e.to_string())
}
