use aes_gcm::{
    aead::{Aead, KeyInit, Payload},
    Aes256Gcm, Key, Nonce,
};
use argon2::{Algorithm, Argon2, Params, Version};
use hkdf::Hkdf;
use rand::{rngs::OsRng, RngCore};
use serde::{Deserialize, Serialize};
use sha2::Sha256;
use thiserror::Error;
use zeroize::{Zeroize, ZeroizeOnDrop, Zeroizing};

/// Standard Argon2id parameters tuned for modern mobile ARM64 hardware:
/// 64 MiB RAM, 3 iterations, 4 parallelism lanes.
pub const ARGON2_MEMORY_KIB: u32 = 65_536;
pub const ARGON2_ITERATIONS: u32 = 3;
pub const ARGON2_PARALLELISM: u32 = 4;
pub const KEY_LEN: usize = 32;
pub const SALT_LEN: usize = 32;
pub const NONCE_LEN: usize = 12;

#[derive(Debug, Error)]
pub enum CryptoError {
    #[error("Failed to derive key with Argon2id")]
    KdfFailure,
    #[error("HKDF context expansion failed")]
    HkdfFailure,
    #[error("AEAD encryption or authentication tag verification failed (invalid password or tampered data)")]
    AeadFailure,
    #[error("Invalid key or nonce length")]
    InvalidLength,
}

/// 256-bit Data Encryption Key (DEK) that automatically wipes itself from RAM when dropped.
#[derive(Clone, Zeroize, ZeroizeOnDrop)]
pub struct DataEncryptionKey([u8; KEY_LEN]);

impl DataEncryptionKey {
    /// Generates a fresh 256-bit random DEK using the OS CSPRNG.
    pub fn generate_random() -> Self {
        let mut bytes = [0u8; KEY_LEN];
        OsRng.fill_bytes(&mut bytes);
        Self(bytes)
    }

    pub fn from_bytes(bytes: [u8; KEY_LEN]) -> Self {
        Self(bytes)
    }

    pub fn as_bytes(&self) -> &[u8; KEY_LEN] {
        &self.0
    }

    /// Derives a dedicated 256-bit subkey for SQLCipher PRAGMA raw hex key via HKDF-SHA256.
    pub fn derive_sqlcipher_raw_key(&self) -> Result<Zeroizing<String>, CryptoError> {
        let hk = Hkdf::<Sha256>::new(None, &self.0);
        let mut subkey = Zeroizing::new([0u8; KEY_LEN]);
        hk.expand(b"superxsecret.v1.sqlcipher.page_key", subkey.as_mut())
            .map_err(|_| CryptoError::HkdfFailure)?;

        let mut hex_key = String::with_capacity(70);
        hex_key.push_str("x'");
        for b in subkey.iter() {
            hex_key.push_str(&format!("{:02x}", b));
        }
        hex_key.push('\'');
        Ok(Zeroizing::new(hex_key))
    }

    /// Derives a dedicated 256-bit subkey for Field-Level AES-256-GCM encryption.
    pub fn derive_field_aead_key(&self) -> Result<Zeroizing<[u8; KEY_LEN]>, CryptoError> {
        let hk = Hkdf::<Sha256>::new(None, &self.0);
        let mut subkey = Zeroizing::new([0u8; KEY_LEN]);
        hk.expand(b"superxsecret.v1.field.aead_key", subkey.as_mut())
            .map_err(|_| CryptoError::HkdfFailure)?;
        Ok(subkey)
    }
}

/// Represents a wrapped DEK slot in the Vault Header.
/// Two slots are stored per vault: Slot A (Primary Vault) and Slot B (Duress/Decoy Vault).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct WrappedKeySlot {
    pub salt: [u8; SALT_LEN],
    pub nonce: [u8; NONCE_LEN],
    pub wrapped_dek_ciphertext: Vec<u8>,
    pub m_cost_kib: u32,
    pub t_cost: u32,
    pub p_lanes: u32,
}

/// Derives a 256-bit Key Encryption Key (KEK) from a password and 32-byte salt using Argon2id + HKDF-SHA256.
pub fn derive_kek_argon2id(
    password: &[u8],
    salt: &[u8; SALT_LEN],
    m_cost_kib: u32,
    t_cost: u32,
    p_lanes: u32,
) -> Result<Zeroizing<[u8; KEY_LEN]>, CryptoError> {
    let params = Params::new(m_cost_kib, t_cost, p_lanes, Some(KEY_LEN))
        .map_err(|_| CryptoError::KdfFailure)?;
    let argon2 = Argon2::new(Algorithm::Argon2id, Version::V0x13, params);

    let mut master_seed = Zeroizing::new([0u8; KEY_LEN]);
    argon2
        .hash_password_into(password, salt, master_seed.as_mut())
        .map_err(|_| CryptoError::KdfFailure)?;

    let hk = Hkdf::<Sha256>::new(Some(salt), master_seed.as_ref());
    let mut kek = Zeroizing::new([0u8; KEY_LEN]);
    hk.expand(b"superxsecret.v1.kek.envelope", kek.as_mut())
        .map_err(|_| CryptoError::HkdfFailure)?;

    Ok(kek)
}

/// Wraps a DataEncryptionKey (DEK) using a password, producing a `WrappedKeySlot`.
pub fn create_wrapped_key_slot(
    password: &[u8],
    dek: &DataEncryptionKey,
    slot_domain_aad: &[u8],
) -> Result<WrappedKeySlot, CryptoError> {
    let mut salt = [0u8; SALT_LEN];
    let mut nonce = [0u8; NONCE_LEN];
    OsRng.fill_bytes(&mut salt);
    OsRng.fill_bytes(&mut nonce);

    let kek = derive_kek_argon2id(
        password,
        &salt,
        ARGON2_MEMORY_KIB,
        ARGON2_ITERATIONS,
        ARGON2_PARALLELISM,
    )?;

    let cipher = Aes256Gcm::new(Key::<Aes256Gcm>::from_slice(kek.as_ref()));
    let payload = Payload {
        msg: dek.as_bytes(),
        aad: slot_domain_aad,
    };

    let wrapped_dek_ciphertext = cipher
        .encrypt(Nonce::from_slice(&nonce), payload)
        .map_err(|_| CryptoError::AeadFailure)?;

    Ok(WrappedKeySlot {
        salt,
        nonce,
        wrapped_dek_ciphertext,
        m_cost_kib: ARGON2_MEMORY_KIB,
        t_cost: ARGON2_ITERATIONS,
        p_lanes: ARGON2_PARALLELISM,
    })
}

/// Unwraps a `WrappedKeySlot` using the candidate password.
pub fn unwrap_key_slot(
    password: &[u8],
    slot: &WrappedKeySlot,
    slot_domain_aad: &[u8],
) -> Result<DataEncryptionKey, CryptoError> {
    let kek = derive_kek_argon2id(
        password,
        &slot.salt,
        slot.m_cost_kib,
        slot.t_cost,
        slot.p_lanes,
    )?;

    let cipher = Aes256Gcm::new(Key::<Aes256Gcm>::from_slice(kek.as_ref()));
    let payload = Payload {
        msg: &slot.wrapped_dek_ciphertext,
        aad: slot_domain_aad,
    };

    let decrypted_vec = Zeroizing::new(
        cipher
            .decrypt(Nonce::from_slice(&slot.nonce), payload)
            .map_err(|_| CryptoError::AeadFailure)?,
    );

    if decrypted_vec.len() != KEY_LEN {
        return Err(CryptoError::InvalidLength);
    }

    let mut dek_bytes = [0u8; KEY_LEN];
    dek_bytes.copy_from_slice(&decrypted_vec);
    Ok(DataEncryptionKey::from_bytes(dek_bytes))
}

/// Encrypts a sensitive record field payload using AES-256-GCM and binds it to
/// `record_aad` (`item_uuid || item_type || schema_version`) to prevent ciphertext transplanting.
pub fn encrypt_field_aead(
    dek: &DataEncryptionKey,
    plaintext: &[u8],
    record_aad: &[u8],
) -> Result<Vec<u8>, CryptoError> {
    let field_key = dek.derive_field_aead_key()?;
    let cipher = Aes256Gcm::new(Key::<Aes256Gcm>::from_slice(field_key.as_ref()));

    let mut nonce = [0u8; NONCE_LEN];
    OsRng.fill_bytes(&mut nonce);

    let ciphertext = cipher
        .encrypt(
            Nonce::from_slice(&nonce),
            Payload {
                msg: plaintext,
                aad: record_aad,
            },
        )
        .map_err(|_| CryptoError::AeadFailure)?;

    // Prepend 12-byte Nonce to Ciphertext+Tag
    let mut output = Vec::with_capacity(NONCE_LEN + ciphertext.len());
    output.extend_from_slice(&nonce);
    output.extend_from_slice(&ciphertext);
    Ok(output)
}

/// Decrypts a sensitive record field payload and verifies the `record_aad` binding.
pub fn decrypt_field_aead(
    dek: &DataEncryptionKey,
    nonce_and_ciphertext: &[u8],
    record_aad: &[u8],
) -> Result<Zeroizing<Vec<u8>>, CryptoError> {
    if nonce_and_ciphertext.len() <= NONCE_LEN + 16 {
        return Err(CryptoError::InvalidLength);
    }

    let (nonce, ciphertext) = nonce_and_ciphertext.split_at(NONCE_LEN);
    let field_key = dek.derive_field_aead_key()?;
    let cipher = Aes256Gcm::new(Key::<Aes256Gcm>::from_slice(field_key.as_ref()));

    let plaintext = Zeroizing::new(
        cipher
            .decrypt(
                Nonce::from_slice(nonce),
                Payload {
                    msg: ciphertext,
                    aad: record_aad,
                },
            )
            .map_err(|_| CryptoError::AeadFailure)?,
    );

    Ok(plaintext)
}

fn derive_item_lock_key(
    item_password: &[u8],
    item_lock_salt: &[u8; SALT_LEN],
) -> Result<Zeroizing<[u8; KEY_LEN]>, CryptoError> {
    let params = Params::new(
        ARGON2_MEMORY_KIB,
        ARGON2_ITERATIONS,
        ARGON2_PARALLELISM,
        Some(KEY_LEN),
    )
    .map_err(|_| CryptoError::KdfFailure)?;
    let argon2 = Argon2::new(Algorithm::Argon2id, Version::V0x13, params);
    let mut master_seed = Zeroizing::new([0u8; KEY_LEN]);
    argon2
        .hash_password_into(item_password, item_lock_salt, master_seed.as_mut())
        .map_err(|_| CryptoError::KdfFailure)?;

    let hk = Hkdf::<Sha256>::new(Some(item_lock_salt), master_seed.as_ref());
    let mut item_key = Zeroizing::new([0u8; KEY_LEN]);
    hk.expand(b"superxsecret.v1.item_lock.aead_key", item_key.as_mut())
        .map_err(|_| CryptoError::HkdfFailure)?;
    Ok(item_key)
}

pub fn build_item_lock_aad(item_uuid: &str, schema_version: u16) -> Vec<u8> {
    format!(
        "superxsecret.v1.item_lock:{}|v{}",
        item_uuid, schema_version
    )
    .into_bytes()
}

pub fn generate_item_lock_salt() -> [u8; SALT_LEN] {
    let mut salt = [0u8; SALT_LEN];
    OsRng.fill_bytes(&mut salt);
    salt
}

pub fn encrypt_item_inner_layer(
    item_password: &[u8],
    item_lock_salt: &[u8; SALT_LEN],
    plaintext: &[u8],
    aad: &[u8],
) -> Result<Vec<u8>, CryptoError> {
    let item_key = derive_item_lock_key(item_password, item_lock_salt)?;
    let cipher = Aes256Gcm::new(Key::<Aes256Gcm>::from_slice(item_key.as_ref()));
    let mut nonce = [0u8; NONCE_LEN];
    OsRng.fill_bytes(&mut nonce);
    let ciphertext = cipher
        .encrypt(
            Nonce::from_slice(&nonce),
            Payload {
                msg: plaintext,
                aad,
            },
        )
        .map_err(|_| CryptoError::AeadFailure)?;

    let mut output = Vec::with_capacity(NONCE_LEN + ciphertext.len());
    output.extend_from_slice(&nonce);
    output.extend_from_slice(&ciphertext);
    Ok(output)
}

pub fn decrypt_item_inner_layer(
    item_password: &[u8],
    item_lock_salt: &[u8; SALT_LEN],
    nonce_and_ciphertext: &[u8],
    aad: &[u8],
) -> Result<Zeroizing<Vec<u8>>, CryptoError> {
    if nonce_and_ciphertext.len() <= NONCE_LEN + 16 {
        return Err(CryptoError::InvalidLength);
    }

    let (nonce, ciphertext) = nonce_and_ciphertext.split_at(NONCE_LEN);
    let item_key = derive_item_lock_key(item_password, item_lock_salt)?;
    let cipher = Aes256Gcm::new(Key::<Aes256Gcm>::from_slice(item_key.as_ref()));
    let plaintext = Zeroizing::new(
        cipher
            .decrypt(
                Nonce::from_slice(nonce),
                Payload {
                    msg: ciphertext,
                    aad,
                },
            )
            .map_err(|_| CryptoError::AeadFailure)?,
    );
    Ok(plaintext)
}

#[cfg(test)]
mod tests {
    use super::{
        build_item_lock_aad, decrypt_item_inner_layer, encrypt_item_inner_layer, SALT_LEN,
    };

    #[test]
    fn item_inner_layer_requires_password_and_record_aad() {
        let salt = [0xA5; SALT_LEN];
        let aad = build_item_lock_aad("item-1", 2);
        let ciphertext =
            encrypt_item_inner_layer(b"separate item password", &salt, b"private", &aad).unwrap();

        let plaintext =
            decrypt_item_inner_layer(b"separate item password", &salt, &ciphertext, &aad).unwrap();
        assert_eq!(plaintext.as_slice(), b"private");
        assert!(decrypt_item_inner_layer(b"wrong password", &salt, &ciphertext, &aad).is_err());
        assert!(decrypt_item_inner_layer(
            b"separate item password",
            &salt,
            &ciphertext,
            &build_item_lock_aad("item-2", 2),
        )
        .is_err());
    }
}
