import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../data/repositories/vault_repository.dart';
import '../../../../domain/models/vault_models.dart';

class VaultViewModel extends ChangeNotifier {
  VaultViewModel({required VaultRepository vaultRepository})
      : _vaultRepository = vaultRepository;

  final VaultRepository _vaultRepository;

  List<VaultTopicSummary> _allItems = const [];

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  DecodedTopicSecret? _activeRevealedSecret;
  DecodedTopicSecret? get activeRevealedSecret => _activeRevealedSecret;

  int _revealSecondsRemaining = 0;
  int get revealSecondsRemaining => _revealSecondsRemaining;

  int _clipboardSecondsRemaining = 0;
  int get clipboardSecondsRemaining => _clipboardSecondsRemaining;
  String? _copiedFieldLabel;
  String? get copiedFieldLabel => _copiedFieldLabel;

  Timer? _revealCountdownTimer;
  Timer? _clipboardCountdownTimer;

  VaultSessionMode? get activeSessionMode => _vaultRepository.activeSessionMode;

  List<VaultTopicSummary> get filteredItems {
    return _allItems.where((item) {
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return item.topic.toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  Future<void> loadVaultSummaries() async {
    _allItems = await _vaultRepository.fetchVaultSummaries();
    notifyListeners();
  }

  Future<void> loadSampleDemoData() async {
    await _vaultRepository.loadSampleDemoData();
    await loadVaultSummaries();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Decrypts a topic's secret payload without immediately displaying it in UI.
  Future<DecodedTopicSecret> decryptSecretPayload(
    String itemUuid, {
    String? overridePassword,
    String? itemPassword,
  }) {
    return _vaultRepository.revealSecretPayloadJit(
      itemUuid,
      overridePassword: overridePassword,
      itemPassword: itemPassword,
    );
  }

  /// Sets the active revealed secret and starts the 15-second ephemeral wipe timer.
  void setActiveRevealedSecret(DecodedTopicSecret secret) {
    _revealCountdownTimer?.cancel();
    _activeRevealedSecret = secret;
    _revealSecondsRemaining = 15;
    notifyListeners();

    _revealCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_revealSecondsRemaining <= 1) {
        hideAndZeroizeRevealedSecret();
      } else {
        _revealSecondsRemaining--;
        notifyListeners();
      }
    });
  }

  /// Just-In-Time (JIT) decryption of a single topic's Secret Text.
  /// Automatically wipes the decrypted secret from RAM after 15 seconds.
  Future<void> revealSecretJit(
    String itemUuid, {
    String? overridePassword,
    String? itemPassword,
  }) async {
    final secret = await decryptSecretPayload(
      itemUuid,
      overridePassword: overridePassword,
      itemPassword: itemPassword,
    );
    setActiveRevealedSecret(secret);
  }

  /// Immediately wipes the JIT revealed secret from memory.
  void hideAndZeroizeRevealedSecret() {
    _revealCountdownTimer?.cancel();
    _revealCountdownTimer = null;
    _activeRevealedSecret = null;
    _revealSecondsRemaining = 0;
    notifyListeners();
  }

  /// Creates a new Topic item (text or media file) in the active vault.
  Future<VaultTopicSummary> createTopic({
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
  }) async {
    final created = await _vaultRepository.saveTopic(
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
    await loadVaultSummaries();
    return created;
  }

  Future<void> deleteTopic(String itemUuid) async {
    await _vaultRepository.deleteTopic(itemUuid);
    if (_activeRevealedSecret?.itemUuid == itemUuid) {
      hideAndZeroizeRevealedSecret();
    }
    await loadVaultSummaries();
  }

  Future<void> updateItemPassword({
    required String itemUuid,
    required String currentItemPassword,
  }) async {
    await _vaultRepository.updateItemPassword(
      itemUuid: itemUuid,
      currentItemPassword: currentItemPassword,
    );
    await loadVaultSummaries();
  }

  Future<void> setItemExtraLock({
    required String itemUuid,
    required String newItemPassword,
    required String passwordHint,
    String? currentItemPassword,
  }) async {
    await _vaultRepository.setItemExtraLock(
      itemUuid: itemUuid,
      newItemPassword: newItemPassword,
      passwordHint: passwordHint,
      currentItemPassword: currentItemPassword,
    );
    await loadVaultSummaries();
  }

  Future<void> removeItemExtraLock({
    required String itemUuid,
    required String itemPassword,
  }) async {
    await _vaultRepository.removeItemExtraLock(
      itemUuid: itemUuid,
      itemPassword: itemPassword,
    );
    await loadVaultSummaries();
  }

  Future<void> verifyItemPassword(
    String itemUuid, {
    String? overridePassword,
    String? itemPassword,
  }) {
    return _vaultRepository.verifyItemPassword(
      itemUuid,
      overridePassword: overridePassword,
      itemPassword: itemPassword,
    );
  }

  Future<void> verifyVaultPassword(
    String itemUuid, {
    String? overridePassword,
  }) {
    return _vaultRepository.verifyVaultPassword(
      itemUuid,
      overridePassword: overridePassword,
    );
  }

  double estimatePasswordEntropyBits(String password) {
    return _vaultRepository.estimatePasswordEntropyBits(password);
  }

  String generateRandomPassword({int length = 20}) {
    return _vaultRepository.generateStrongPassword(length: length);
  }

  /// Exports a single item into an encrypted `.sxsi` (`"SXSI"`) packet with a File Password.
  Future<String> exportSingleItemSxsi({
    required String itemUuid,
    required String filePassword,
    String? itemPassword,
    String? overridePassword,
  }) {
    return _vaultRepository.exportSingleItemSxsi(
      itemUuid: itemUuid,
      filePassword: filePassword,
      itemPassword: itemPassword,
      overridePassword: overridePassword,
    );
  }

  /// Decodes and imports a shared `.sxsi` (`"SXSI"`) packet into the active vault.
  Future<VaultTopicSummary> importSingleItemSxsi({
    required String sxsiPacket,
    required String filePassword,
  }) async {
    final imported = await _vaultRepository.importSingleItemSxsi(
      sxsiPacket: sxsiPacket,
      filePassword: filePassword,
    );
    await loadVaultSummaries();
    return imported;
  }

  /// Copies a secret to the hardened OS clipboard (`EXTRA_IS_SENSITIVE` / `.localOnly`)
  /// and starts a 30-second auto-wipe countdown.
  Future<void> copySecretWithAutoClear({
    required String label,
    required String secretValue,
    int ttlSeconds = 30,
  }) async {
    await _vaultRepository.copySecretToHardenedClipboard(
      secretValue,
      ttlSeconds: ttlSeconds,
    );
    _clipboardCountdownTimer?.cancel();
    _copiedFieldLabel = label;
    _clipboardSecondsRemaining = ttlSeconds;
    notifyListeners();

    _clipboardCountdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (_clipboardSecondsRemaining <= 1) {
          clearClipboardImmediately();
        } else {
          _clipboardSecondsRemaining--;
          notifyListeners();
        }
      },
    );
  }

  Future<void> clearClipboardImmediately() async {
    _clipboardCountdownTimer?.cancel();
    _clipboardCountdownTimer = null;
    _clipboardSecondsRemaining = 0;
    _copiedFieldLabel = null;
    await _vaultRepository.clearClipboardNow();
    notifyListeners();
  }

  Future<Uint8List> exportSxsEncryptedFile({
    required String masterPasswordVerification,
    required String backupFilePassword,
  }) {
    return _vaultRepository.exportSxsBackup(
      verifyMasterPassword: masterPasswordVerification,
      backupEncryptionPassword: backupFilePassword,
    );
  }

  Future<void> restoreSxsEncryptedFile({
    required Uint8List backupBytes,
    required String backupFilePassword,
  }) async {
    await _vaultRepository.restoreSxsBackup(
      backupBytes: backupBytes,
      backupFilePassword: backupFilePassword,
    );
    hideAndZeroizeRevealedSecret();
    await loadVaultSummaries();
  }

  @override
  void dispose() {
    _revealCountdownTimer?.cancel();
    _clipboardCountdownTimer?.cancel();
    super.dispose();
  }
}
