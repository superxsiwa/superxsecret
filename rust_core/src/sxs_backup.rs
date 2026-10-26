//! `.sxs` (SuperXSecret Vault) Custom Encrypted Binary Container Format
//!
//! Byte Layout (64-Byte Authenticated Header + Ciphertext + 16-Byte GCM Tag):
//! - `0x00..0x04` (4B)  : Magic Bytes `"SXSV"` (`0x53 0x58 0x53 0x56`)
//! - `0x04..0x06` (2B)  : Format Version `0x0001` (Big-Endian u16)
//! - `0x06`       (1B)  : KDF Algorithm ID (`0x01` = Argon2id)
//! - `0x07`       (1B)  : Cipher Algorithm ID (`0x01` = AES-256-GCM)
//! - `0x08..0x14` (12B) : KDF Params (`m_cost` u32 BE, `t_cost` u32 BE, `p_lanes` u32 BE)
//! - `0x14..0x34` (32B) : Fresh Export CSPRNG Salt (never reuses local DB salt)
//! - `0x34..0x40` (12B) : AES-256-GCM Nonce
//! - `0x40..N`          : Encrypted Snapshot Payload + 16-Byte GCM Auth Tag
//!
//! **Integrity Guarantee**: Bytes `0x00..0x40` (the entire 64-byte header) are fed as
//! AAD (Associated Authenticated Data) into AES-256-GCM. Modifying a single bit of the
//! header causes immediate authentication failure prior to parsing.

use crate::crypto::{
    derive_kek_argon2id, CryptoError, ARGON2_ITERATIONS, ARGON2_MEMORY_KIB, ARGON2_PARALLELISM,
    NONCE_LEN, SALT_LEN,
};
use aes_gcm::{
    aead::{Aead, KeyInit, Payload},
    Aes256Gcm, Key, Nonce,
};
use rand::{rngs::OsRng, RngCore};
use thiserror::Error;
use zeroize::Zeroizing;

pub const SXS_MAGIC: [u8; 4] = [0x53, 0x58, 0x53, 0x56]; // "SXSV" (Full Vault Backup)
pub const SXSI_MAGIC: [u8; 4] = [0x53, 0x58, 0x53, 0x49]; // "SXSI" (Single-Item Share)
pub const SXS_FORMAT_VERSION: u16 = 1;
pub const SXS_KDF_ARGON2ID: u8 = 0x01;
pub const SXS_CIPHER_AES256GCM: u8 = 0x01;
pub const SXS_HEADER_LEN: usize = 64;

#[derive(Debug, Error)]
pub enum SxsBackupError {
    #[error("Invalid .sxs/.sxsi file magic bytes or corrupted header")]
    InvalidMagicOrHeader,
    #[error("Unsupported .sxs/.sxsi format version: {0}")]
    UnsupportedVersion(u16),
    #[error("Unsupported KDF or Cipher algorithm ID in header")]
    UnsupportedAlgorithm,
    #[error("Decryption failed: Invalid File Password or tampered file")]
    DecryptionFailed,
}

fn encode_container_with_magic(
    magic: [u8; 4],
    password: &[u8],
    payload_bytes: &[u8],
) -> Result<Vec<u8>, SxsBackupError> {
    let mut export_salt = [0u8; SALT_LEN];
    let mut nonce = [0u8; NONCE_LEN];
    OsRng.fill_bytes(&mut export_salt);
    OsRng.fill_bytes(&mut nonce);

    // Construct the 64-byte binary header
    let mut header = Vec::with_capacity(SXS_HEADER_LEN);
    header.extend_from_slice(&magic);
    header.extend_from_slice(&SXS_FORMAT_VERSION.to_be_bytes());
    header.push(SXS_KDF_ARGON2ID);
    header.push(SXS_CIPHER_AES256GCM);
    header.extend_from_slice(&ARGON2_MEMORY_KIB.to_be_bytes());
    header.extend_from_slice(&ARGON2_ITERATIONS.to_be_bytes());
    header.extend_from_slice(&ARGON2_PARALLELISM.to_be_bytes());
    header.extend_from_slice(&export_salt);
    header.extend_from_slice(&nonce);
    debug_assert_eq!(header.len(), SXS_HEADER_LEN);

    let export_key = derive_kek_argon2id(
        password,
        &export_salt,
        ARGON2_MEMORY_KIB,
        ARGON2_ITERATIONS,
        ARGON2_PARALLELISM,
    )
    .map_err(|_| SxsBackupError::DecryptionFailed)?;

    let cipher = Aes256Gcm::new(Key::<Aes256Gcm>::from_slice(export_key.as_ref()));
    let ciphertext_with_tag = cipher
        .encrypt(
            Nonce::from_slice(&nonce),
            Payload {
                msg: payload_bytes,
                aad: &header, // Bind the entire 64-byte header into AES-GCM AAD!
            },
        )
        .map_err(|_| SxsBackupError::DecryptionFailed)?;

    let mut out = Vec::with_capacity(SXS_HEADER_LEN + ciphertext_with_tag.len());
    out.extend_from_slice(&header);
    out.extend_from_slice(&ciphertext_with_tag);
    Ok(out)
}


fn decode_container_with_magic(
    expected_magic: [u8; 4],
    password: &[u8],
    file_bytes: &[u8],
) -> Result<Zeroizing<Vec<u8>>, SxsBackupError> {
    if file_bytes.len() <= SXS_HEADER_LEN + 16 {
        return Err(SxsBackupError::InvalidMagicOrHeader);
    }

    let (header, ciphertext_with_tag) = file_bytes.split_at(SXS_HEADER_LEN);

    if header[0..4] != expected_magic {
        return Err(SxsBackupError::InvalidMagicOrHeader);
    }

    let version = u16::from_be_bytes([header[4], header[5]]);
    if version != SXS_FORMAT_VERSION {
        return Err(SxsBackupError::UnsupportedVersion(version));
    }

    let kdf_id = header[6];
    let cipher_id = header[7];
    if kdf_id != SXS_KDF_ARGON2ID || cipher_id != SXS_CIPHER_AES256GCM {
        return Err(SxsBackupError::UnsupportedAlgorithm);
    }

    let m_cost = u32::from_be_bytes([header[8], header[9], header[10], header[11]]);
    let t_cost = u32::from_be_bytes([header[12], header[13], header[14], header[15]]);
    let p_lanes = u32::from_be_bytes([header[16], header[17], header[18], header[19]]);

    // Sanity bounds on KDF header parameters to prevent DoS via malicious header values
    if !(16_384..=262_144).contains(&m_cost)
        || !(1..=16).contains(&t_cost)
        || !(1..=16).contains(&p_lanes)
    {
        return Err(SxsBackupError::InvalidMagicOrHeader);
    }

    let mut export_salt = [0u8; SALT_LEN];
    export_salt.copy_from_slice(&header[20..52]);

    let mut nonce = [0u8; NONCE_LEN];
    nonce.copy_from_slice(&header[52..64]);

    let export_key = derive_kek_argon2id(password, &export_salt, m_cost, t_cost, p_lanes)
        .map_err(|_| SxsBackupError::DecryptionFailed)?;

    let cipher = Aes256Gcm::new(Key::<Aes256Gcm>::from_slice(export_key.as_ref()));
    let decrypted = cipher
        .decrypt(
            Nonce::from_slice(&nonce),
            Payload {
                msg: ciphertext_with_tag,
                aad: header,
            },
        )
        .map_err(|_: CryptoError| SxsBackupError::DecryptionFailed)
        .or(Err(SxsBackupError::DecryptionFailed))?;

    Ok(Zeroizing::new(decrypted))
}

/// Encodes a full vault JSON snapshot into an encrypted `.sxs` (`"SXSV"`) binary container.
pub fn export_to_sxs_bytes(
    backup_password: &[u8],
    snapshot_json_bytes: &[u8],
) -> Result<Vec<u8>, SxsBackupError> {
    encode_container_with_magic(SXS_MAGIC, backup_password, snapshot_json_bytes)
}

/// Validates and decrypts an encrypted `.sxs` (`"SXSV"`) binary container using the user-supplied password.
pub fn import_from_sxs_bytes(
    backup_password: &[u8],
    sxs_file_bytes: &[u8],
) -> Result<Zeroizing<Vec<u8>>, SxsBackupError> {
    decode_container_with_magic(SXS_MAGIC, backup_password, sxs_file_bytes)
}

/// Encodes a single Topic + Secret Text JSON payload into an encrypted `.sxsi` (`"SXSI"`) binary container.
pub fn export_single_item_sxsi_bytes(
    file_password: &[u8],
    topic_json_bytes: &[u8],
) -> Result<Vec<u8>, SxsBackupError> {
    encode_container_with_magic(SXSI_MAGIC, file_password, topic_json_bytes)
}

/// Validates and decrypts an encrypted `.sxsi` (`"SXSI"`) single-item container using the sender's File Password.
pub fn import_single_item_sxsi_bytes(
    file_password: &[u8],
    sxsi_file_bytes: &[u8],
) -> Result<Zeroizing<Vec<u8>>, SxsBackupError> {
    decode_container_with_magic(SXSI_MAGIC, file_password, sxsi_file_bytes)
}


