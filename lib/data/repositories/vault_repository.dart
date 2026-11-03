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
    String passwordHint = '',
  }) {
    return _rustFfiService.initializeDualSlotVault(
      mainPassword: mainPassword,
      secondaryPassword: secondaryPassword,
      passwordHint: passwordHint,
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

  Future<DecodedTopicSecret> revealSecretPayloadJit(
    String itemUuid, {
    String? overridePassword,
    String? itemPassword,
  }) {
    return _rustFfiService.decryptPayloadJit(
      itemUuid,
      overridePassword: overridePassword,
      itemPassword: itemPassword,
    );
  }

  Future<void> verifyVaultPassword(
    String itemUuid, {
    String? overridePassword,
  }) {
    return _rustFfiService.verifyVaultPassword(
      itemUuid,
      overridePassword: overridePassword,
    );
  }

  Future<void> verifyItemPassword(
    String itemUuid, {
    String? overridePassword,
    String? itemPassword,
  }) {
    return _rustFfiService.verifyItemPassword(
      itemUuid,
      overridePassword: overridePassword,
      itemPassword: itemPassword,
    );
  }

  Future<void> updateItemPassword({
    required String itemUuid,
    required String currentItemPassword,
  }) {
    return _rustFfiService.updateItemPassword(
      itemUuid: itemUuid,
      currentItemPassword: currentItemPassword,
    );
  }

  Future<void> setItemExtraLock({
    required String itemUuid,
    required String newItemPassword,
    required String passwordHint,
    String? currentItemPassword,
  }) {
    return _rustFfiService.setItemExtraLock(
      itemUuid: itemUuid,
      newItemPassword: newItemPassword,
      passwordHint: passwordHint,
      currentItemPassword: currentItemPassword,
    );
  }

  Future<void> removeItemExtraLock({
    required String itemUuid,
    required String itemPassword,
  }) {
    return _rustFfiService.removeItemExtraLock(
      itemUuid: itemUuid,
      itemPassword: itemPassword,
    );
  }

  Future<VaultTopicSummary> saveTopic({
    required String topic,
    required String secretText,
    bool hasExtraLock = false,
    String? itemPassword,
    String passwordHint = '',
    VaultCipherType cipherType = VaultCipherType.aes256Gcm,
    VaultItemCategory category = VaultItemCategory.text,
    String? fileName,
    int? fileSizeBytes,
    String? mimeType,
    Uint8List? rawBytes,
  }) {
    return _rustFfiService.createNewTopic(
      topic: topic,
      secretText: secretText,
      hasExtraLock: hasExtraLock,
      itemPassword: itemPassword,
      passwordHint: passwordHint,
      cipherType: cipherType,
      category: category,
      fileName: fileName,
      fileSizeBytes: fileSizeBytes,
      mimeType: mimeType,
      rawBytes: rawBytes,
    );
  }

  Future<void> deleteTopic(String itemUuid) {
    return _rustFfiService.deleteTopic(itemUuid);
  }

  String generateStrongPassword({int length = 20}) {
    return _rustFfiService.generateStrongPassword(length: length);
  }

  Future<String> exportSingleItemSxsi({
    required String itemUuid,
    required String filePassword,
    String? itemPassword,
    String? overridePassword,
  }) {
    return _rustFfiService.exportSingleItemSxsi(
      itemUuid: itemUuid,
      filePassword: filePassword,
      itemPassword: itemPassword,
      overridePassword: overridePassword,
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

  Future<void> restoreSxsBackup({
    required Uint8List backupBytes,
    required String backupFilePassword,
  }) {
    return _rustFfiService.restoreSxsEncryptedContainer(
      containerBytes: backupBytes,
      backupFilePassword: backupFilePassword,
    );
  }

  Future<void> initFromStorage() => _rustFfiService.initFromStorage();

  Future<void> wipeAllVaultData() => _rustFfiService.wipeAllVaultData();
}
