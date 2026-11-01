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

class VaultTopicSummary {
  const VaultTopicSummary({
    required this.itemUuid,
    required this.topic,
    required this.updatedAt,
    this.passwordHint = '',
  });

  final String itemUuid;
  final String topic;
  final DateTime updatedAt;
  final String passwordHint;
}

class DecodedTopicSecret {
  const DecodedTopicSecret({
    required this.itemUuid,
    required this.topic,
    required this.secretText,
    this.passwordHint = '',
  });

  final String itemUuid;
  final String topic;
  final String secretText;
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
