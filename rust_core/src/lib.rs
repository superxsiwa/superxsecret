//! SuperXSecret Rust Security Core (v1.5)
//!
//! 100% Offline, Zero-Knowledge Cryptographic Engine:
//! - Unified Data Model: `Topic` + optional `Tag` + AES-256-GCM `Secret Text` with Record AAD
//! - Argon2id (m=64MB, t=3, p=4) + HKDF-SHA256 Key Hierarchy (Password-Only, Zero Biometrics)
//! - Dual-Vault Envelope Encryption (Main Vault Slot A + Secondary Vault Slot B)
//! - SQLCipher 4.x Full-Database Encryption + Per-Record AES-256-GCM with AAD
//! - `.sxs` ("SXSV") Full Backup & `.sxsi` ("SXSI") Single-Item Share Containers with Header AAD

pub mod api;
pub mod crypto;
pub mod sxs_backup;
pub mod totp;
pub mod vault_db;


