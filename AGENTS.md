# SuperXSecret — Shared Project Memory for Agents (`AGENTS.md`)

This file serves as the persistent shared memory for all AI agents, subagents, and `/teamwork` peers operating in the `superxsecret` workspace. It is automatically loaded into context for every session in this repository.

---

## 1. Project Overview & Core Identity

- **Product Name:** SuperXSecret
- **Category:** 100% Offline-First, Zero-Knowledge Mobile Secret Vault (iOS & Android)
- **Core Vault Data Model (Unified Topic + Encrypted Text):**
  - Instead of rigid, separate schemas or category/tag buttons (`Email`, `Bank`, `Crypto`), every vault item uses a streamlined, universal 2-field structure:
    1. **Topic** (Short title visible in the unlocked list & searchable metadata — no category/tag buttons or badges)
    2. **Encrypted Secret Text (`encrypted_payload`)** (Free-form text encrypted via AES-256-GCM with AAD — flexible enough to store passwords, credit card details, crypto seed phrases, or private notes in one simple format)
- **Key Differentiator (Dual-Vault Architecture):** Dual-Slot Vault Header supporting both a **Main Password (Slot A)** and a **Secondary Password (Slot B)** that opens a completely separate **Secondary Vault** (useful for work/personal separation or plausible deniability). Never display any "Fake" or "Decoy" label on the unlocked vault screen—both vaults must look 100% identical.
- **Monetization Model:** Freemium (up to 15 items free) + One-Time "Pro Lifetime Unlock" verified 100% offline via local IPC/XPC cryptographic receipt signatures (Google Play Billing RSA / Apple StoreKit 2 JWS) inside the Rust native core.

---

## 2. Non-Negotiable Security Invariants (Hard Rules for All Agents)

When modifying or extending any code in this repository, every agent MUST enforce these security rules:

1. **Verifiable Zero-Network & Zero-Permission Footprint (No Biometrics):**
   - NEVER add `android.permission.INTERNET`, `ACCESS_NETWORK_STATE`, `USE_BIOMETRIC`, `NSFaceIDUsageDescription`, or any HTTP/network client package to `pubspec.yaml`, `Cargo.toml`, `AndroidManifest.xml`, or `Info.plist`.
   - Keep `tools:node="remove"` on network permissions in `android/app/src/main/AndroidManifest.xml`.
   - **No Biometric Unlock:** Vault unlocking is strictly 100% password-based (Master Password Slot A or Duress Password Slot B). Never cache or wrap `DEK` in OS Biometric Keychain/Keystore—this guarantees true Plausible Deniability and protects against forced physical fingerprint/FaceID unlocking.
2. **2-Tier Envelope Encryption (`KEK` + `DEK`) & Dual-Slot Architecture:**
   - Never encrypt vault records directly with a password-derived key.
   - Derive `KEK` via `Argon2id (m=65536 KiB / 64 MiB, t=3, p=4)` + `HKDF-SHA256`.
   - Use `KEK` to unwrap the 256-bit random `DEK` (`DataEncryptionKey` wrapped in `ZeroizeOnDrop` in Rust).
3. **Defense-in-Depth Database + Field-Level AEAD:**
   - **Layer 1 (Full DB):** SQLCipher 4.x (`cipher_page_size = 4096`, `cipher_memory_security = ON`, `secure_delete = ON`).
   - **Layer 2 (Per-Record Secret Payload):** Encrypt sensitive fields into `encrypted_payload` using **AES-256-GCM** with deterministic **AAD** (`superxsecret.v1.record:{item_uuid}|{item_type}|v{schema_version}`) to prevent ciphertext transplanting across rows.
4. **`.sxs` Full Backup & `.sxsi` Single-Item Encrypted Sharing Format (`"SXSV"` / `"SXSI"`):**
   - **Full Vault Backup (`.sxs`, Magic `"SXSV"` `0x53 0x58 0x53 0x56`):** Exports all topics in the active vault for device migration/backup.
   - **Per-Item Encrypted File / Text Share (`.sxsi`, Magic `"SXSI"` `0x53 0x58 0x53 0x49`):** Allows exporting a **single Topic + Secret Text** encrypted with a dedicated **Share Password** (via Argon2id + fresh 32-byte salt + AES-256-GCM Header AAD) so the user can send just one secret item to a friend, and allows importing/decoding any received security file by entering its password.
   - Always require Master Password re-verification before exporting full backups, and require the Decryption Password before decoding/importing any file.
5. **UI & OS Hardening Standards:**
   - Follow Flutter MVVM + Repository layered architecture (`lib/domain`, `lib/data`, `lib/ui/core`, `lib/ui/features`).
   - All `TextField` widgets handling passwords, notes, or search queries MUST set:
     `enableIMEPersonalizedLearning: false`, `autocorrect: false`, `enableSuggestions: false`.
   - Decrypt secret payloads **Just-In-Time (JIT)** only when the user taps Reveal, and auto-zeroize after **15 seconds**.
   - Clipboard copies must go through `OsHardeningService.copySensitiveClipboard` (`EXTRA_IS_SENSITIVE` on Android 13+, `.localOnly: true` + `.expirationDate` on iOS) with a **30-second auto-wipe timer**.
   - **Short & Simple UI Copy:** Keep all item names, captions, labels, and button text in the app short, clean, and easy to read (e.g., `Unlock`, `New`, `Import`, `Share`, `View`, `Copy`, `Lock`, `Topic`, `Secret Text`). Avoid long technical sentences on UI controls.

---

## 3. Codebase Map

- `docs/DEVELOPER_GUIDE.md` — Complete v1.5 SRS, Use Case, Sequence, Class & ER Diagrams, and 4-Sprint Developer Implementation Plan.
- `ARCHITECTURE.md` — System blueprint, Dual-Slot cryptographic design, and Sprint task checklist.
- `rust_core/` — Native Rust Cryptography & Storage Engine (`superxsecret_core`):
  - `rust_core/src/crypto.rs` — Argon2id, HKDF-SHA256, `DataEncryptionKey` (`ZeroizeOnDrop`), Dual-Slot wrapping, Field AES-256-GCM with AAD.
  - `rust_core/src/vault_db.rs` — SQLCipher 4.x connection pragma hardening & CRUD operations.
  - `rust_core/src/sxs_backup.rs` — `.sxs` (`SXSV`) 64-byte authenticated header encoder/decoder.
  - `rust_core/src/totp.rs` — Offline RFC 6238 TOTP (Base32 + HMAC-SHA1) 6-digit generator.
  - `rust_core/src/api.rs` — FFI entrypoint functions for Flutter.
- `android/app/src/main/` — Android Native Hardening:
  - `AndroidManifest.xml` & `res/xml/data_extraction_rules.xml` — Strips internet permissions & blocks cloud/ADB backup extraction.
  - `kotlin/com/superxsecret/vault/MainActivity.kt` — `FLAG_SECURE`, Android 13+ sensitive clipboard auto-clear, `ACTION_SCREEN_OFF` auto-lock, Root/Magisk/Frida checks.
- `ios/Runner/` — iOS Native Hardening:
  - `Info.plist` — `ITSAppUsesNonExemptEncryption` & ATS lockdown.
  - `AppDelegate.swift` — App Switcher blur shield, screen recording detector, `.localOnly` expiring pasteboard, Jailbreak/DYLD checks.
- `lib/` — Flutter Application (MVVM Layered Architecture):
  - `lib/domain/models/vault_models.dart` — Domain models (`VaultSessionMode`, `VaultItemSummary`, `RevealedSecretPayload` subtypes).
  - `lib/data/services/` — `rust_vault_ffi_service.dart` & `os_hardening_service.dart`.
  - `lib/data/repositories/vault_repository.dart` — Single source of truth repository.
  - `lib/ui/core/` — `app_theme.dart`, `privacy_curtain_wrapper.dart`, `scrambled_pin_pad.dart`.
  - `lib/ui/features/auth/` — `auth_view_model.dart` & `lock_screen_view.dart` (Master/Duress unlock, Entropy meter, Biometric trigger).
  - `lib/ui/features/vault/` — `vault_view_model.dart` & `vault_dashboard_view.dart` (Metadata list, 15s JIT reveal, 30s clipboard countdown, live TOTP, `.sxs` export dialog).
- `test/vault_architecture_test.dart` — Unit tests for Dual-Slot isolation and `.sxs` magic header verification.

---

## 4. Current Progress & Next Backlog Items for Agents (See `docs/DEVELOPER_GUIDE.md`)

- **[DONE] Phase 1:** Initial scaffolding, Android/iOS Zero-Permission & No-Biometric Hardening, and Interactive Prototype v1.5.
- **[DONE] Sprint 1 — Rust Core Refactoring (`rust_core/`):** Unified `vault_topics` schema, `MainVault` / `SecondaryVault` naming, and `.sxsi` (`"SXSI"`) single-item encrypted file codec.
- **[DONE] Sprint 2 — Flutter Domain & Data Layer (`lib/domain/` & `lib/data/`):** Streamline models to `VaultTopicSummary` & `DecodedTopicSecret`, and wire `.sxsi` single-item share/import.
- **[DONE] Sprint 3 — Flutter UI Views & Modals (`lib/ui/`):** Short & simple UI copy, remove vault slot badge (`MAIN`/`FAKE`) from dashboard, and add `+ New Topic`, `📤 Share (.sxsi)`, and `📥 Import File (.sxsi)` modals.
- **[DONE] Sprint 4 — Automated Tests (`test/`):** Update `test/vault_architecture_test.dart` for Main/Secondary vault isolation, Topic CRUD, and `.sxsi` / `.sxs` verification.


---

## 5. User Communication & Language Preferences

- **Primary Language:** Always communicate with the user in **English**.
- **English Coaching Rule:** At the top of every response, include a brief `🇬🇧 English Suggestion` box that offers a natural, native-sounding English phrasing for the user's prompt or instruction to help them improve their English.


