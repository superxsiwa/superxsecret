/// Clean Domain Models for SuperXSecret Vault (v1.5)
///
/// Enforces separation between non-sensitive metadata (`VaultTopicSummary`)
/// kept in list views and sensitive secrets (`DecodedTopicSecret`) decrypted
/// Just-In-Time (JIT) for a 15-second ephemeral window.

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
    required this.tag,
    required this.updatedAt,
  });

  final String itemUuid;
  final String topic;
  final String tag;
  final DateTime updatedAt;
}

class DecodedTopicSecret {
  const DecodedTopicSecret({
    required this.itemUuid,
    required this.topic,
    required this.tag,
    required this.secretText,
  });

  final String itemUuid;
  final String topic;
  final String tag;
  final String secretText;
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


