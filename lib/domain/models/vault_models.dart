/// Clean Domain Models for SuperXSecret Vault (v1.5)
///
/// Enforces separation between non-sensitive metadata (`VaultTopicSummary`)
/// kept in list views and sensitive secrets (`DecodedTopicSecret`) decrypted
/// Just-In-Time (JIT) for a 15-second ephemeral window.
library;

enum VaultSessionMode {
  mainVault,
  secondaryVault,
}

class DeviceSecurityPosture {
  const DeviceSecurityPosture({
    required this.zeroNetworkPermissionVerified,
    required this.isScreenGuardActive,
    required this.isCompromised,
    required this.hasRootOrJailbreak,
    required this.isDebuggerOrFridaDetected,
    required this.sqlCipherActive,
  });

  final bool zeroNetworkPermissionVerified;
  final bool isScreenGuardActive;
  final bool isCompromised;
  final bool hasRootOrJailbreak;
  final bool isDebuggerOrFridaDetected;
  final bool sqlCipherActive;
}

enum VaultCipherType {
  aes256Gcm,
  chacha20Poly1305,
  xchacha20Poly1305,
  aes256CbcHmacSha512,
  dualCipher;

  String get badgeLabel {
    switch (this) {
      case VaultCipherType.aes256Gcm:
        return 'AES-256-GCM';
      case VaultCipherType.chacha20Poly1305:
        return 'ChaCha20-Poly1305';
      case VaultCipherType.xchacha20Poly1305:
        return 'XChaCha20-Poly1305';
      case VaultCipherType.aes256CbcHmacSha512:
        return 'AES-256-CBC + SHA512';
      case VaultCipherType.dualCipher:
        return 'Dual (AES + XChaCha20)';
    }
  }
}

class VaultTopicSummary {
  const VaultTopicSummary({
    required this.itemUuid,
    required this.topic,
    required this.updatedAt,
    this.hasExtraLock = false,
    this.passwordHint = '',
    this.cipherType = VaultCipherType.aes256Gcm,
  });

  final String itemUuid;
  final String topic;
  final DateTime updatedAt;
  final bool hasExtraLock;
  final String passwordHint;
  final VaultCipherType cipherType;
}

class DecodedTopicSecret {
  const DecodedTopicSecret({
    required this.itemUuid,
    required this.topic,
    required this.secretText,
    this.hasExtraLock = false,
    this.passwordHint = '',
    this.cipherType = VaultCipherType.aes256Gcm,
  });

  final String itemUuid;
  final String topic;
  final String secretText;
  final bool hasExtraLock;
  final String passwordHint;
  final VaultCipherType cipherType;
}

class ItemLockedException extends StateError {
  ItemLockedException(this.passwordHint)
      : super('Item password did not authenticate');

  final String passwordHint;
}

class VaultItemPasswordException extends StateError {
  VaultItemPasswordException(this.passwordHint)
      : super('Item password did not authenticate');

  final String passwordHint;
}

class TotpCodeState {
  const TotpCodeState({
    required this.code,
    required this.remainingSeconds,
    this.periodSeconds = 30,
  });

  final String code;
  final int remainingSeconds;
  final int periodSeconds;
}
