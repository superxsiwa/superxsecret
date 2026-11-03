# SuperXSecret Privacy Policy

**Effective Date:** November 3, 2026  
**License:** Open Source Security Reference  
**Hosted Policy URL:** `https://superxsiwa.github.io/superxsecret/privacy_policy.html`

---

## 🛡️ The Zero-Knowledge Guarantee

At **SuperXSecret**, your privacy is absolute. The application is designed from the silicon up to be **100% Offline with Zero Network Permissions**.

### Summary of Protections:
- 🚫 **0 Internet Permissions:** The application manifest strips `android.permission.INTERNET`, `ACCESS_NETWORK_STATE`, and `ACCESS_WIFI_STATE`. The OS enforces that no network sockets can ever be opened.
- 🚫 **0 Analytics or Telemetry:** No tracking SDKs (no Firebase, Google Analytics, telemetry, or crash loggers).
- 🚫 **0 Account Requirements:** No email, phone number, login, or registration.
- 🚫 **0 Cloud Storage:** No sync servers, cloud databases, or third-party storage.
- 🚫 **0 Automatic Cloud Backup:** Explicitly configures `android:allowBackup="false"` to prevent Google Drive from uploading vault databases.
- 🔒 **Zero-Knowledge Encryption:** All topic secrets and files are encrypted locally with authenticated ciphers (AES-256-GCM, XChaCha20-Poly1305, Dual-Cipher) with Argon2id KDF.
- ⚠️ **Zero Password Recovery:** There are no master keys or backdoor recovery mechanisms. Forgotten passwords cannot be recovered under any circumstance.

---

## 📄 Open Source & Auditing
SuperXSecret source code is openly auditable at:
`https://github.com/superxsiwa/superxsecret`

