import 'package:flutter/foundation.dart';
import '../../domain/models/vault_models.dart';
import '../services/os_hardening_service.dart';
import '../services/rust_vault_ffi_service.dart';

/// Single Source of Truth Repository coordinating the Rust Security Core
/// and Native OS Hardening Controls.
class VaultRepository {
  VaultRepository({
    required RustVaultFfiService rustFfiService,
    required OsHardeningService osHardeningService,
  })  : _rustFfiService = rustFfiService,
        _osHardeningService = osHardeningService;

  final RustVaultFfiService _rustFfiService;
  final OsHardeningService _osHardeningService;

  bool get isVaultInitialized => _rustFfiService.isVaultInitialized;
  VaultSessionMode? get activeSessionMode => _rustFfiService.activeSessionMode;

  void bindOsSecurityCallbacks({
    required VoidCallback onScreenOffAutoLock,
    required ValueChanged<bool> onScreenRecordingDetected,
    required VoidCallback onClipboardCleared,
  }) {
    _osHardeningService.onNativeScreenOffLock = onScreenOffAutoLock;
    _osHardeningService.onScreenRecordingChanged = onScreenRecordingDetected;
    _osHardeningService.onClipboardClearedByOs = onClipboardCleared;
  }

  Future<DeviceSecurityPosture> checkDeviceSecurityPosture() {
    return _osHardeningService.checkDeviceIntegrity();
  }

  double estimatePasswordEntropyBits(String password) {
    return _rustFfiService.calculatePasswordEntropyBits(password);
  }

  Future<void> setupDualSlotVault({
    required String mainPassword,
    required String secondaryPassword,
  }) {
    return _rustFfiService.initializeDualSlotVault(
      mainPassword: mainPassword,
      secondaryPassword: secondaryPassword,
    );
  }

  Future<VaultSessionMode> unlockVault(String password) {
    return _rustFfiService.unlockVault(password);
  }

  void lockVaultImmediately() {
    _rustFfiService.lockAndZeroizeVault();
  }

  Future<List<VaultTopicSummary>> fetchVaultSummaries() {
    return _rustFfiService.listSummaries();
  }

  Future<DecodedTopicSecret> revealSecretPayloadJit(String itemUuid) {
    return _rustFfiService.decryptPayloadJit(itemUuid);
  }

  Future<VaultTopicSummary> saveTopic({
    required String topic,
    required String secretText,
  }) {
    return _rustFfiService.createNewTopic(
      topic: topic,
      secretText: secretText,
    );
  }

  String generateStrongPassword({int length = 20}) {
    return _rustFfiService.generateStrongPassword(length: length);
  }

  Future<String> exportSingleItemSxsi({
    required String itemUuid,
    required String filePassword,
  }) {
    return _rustFfiService.exportSingleItemSxsi(
      itemUuid: itemUuid,
      filePassword: filePassword,
    );
  }

  Future<VaultTopicSummary> importSingleItemSxsi({
    required String sxsiPacket,
    required String filePassword,
  }) {
    return _rustFfiService.importSingleItemSxsi(
      sxsiPacket: sxsiPacket,
      filePassword: filePassword,
    );
  }


  TotpCodeState computeLiveTotp(String base32Secret, DateTime now) {
    return _rustFfiService.computeOfflineTotp(base32Secret, now);
  }

  Future<void> copySecretToHardenedClipboard(
    String secret, {
    int ttlSeconds = 30,
  }) {
    return _osHardeningService.copySensitiveClipboard(
      secret,
      ttlSeconds: ttlSeconds,
    );
  }

  Future<void> clearClipboardNow() {
    return _osHardeningService.clearClipboardNow();
  }

  Future<Uint8List> exportSxsBackup({
    required String verifyMasterPassword,
    required String backupEncryptionPassword,
  }) {
    return _rustFfiService.exportSxsEncryptedContainer(
      verifyMasterPassword: verifyMasterPassword,
      backupEncryptionPassword: backupEncryptionPassword,
    );
  }
}

