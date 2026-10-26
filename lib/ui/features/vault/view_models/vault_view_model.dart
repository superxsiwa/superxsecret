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

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Just-In-Time (JIT) decryption of a single topic's Secret Text.
  /// Automatically wipes the decrypted secret from RAM after 15 seconds.
  Future<void> revealSecretJit(String itemUuid) async {
    _revealCountdownTimer?.cancel();
    final secret = await _vaultRepository.revealSecretPayloadJit(itemUuid);
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

  /// Immediately wipes the JIT revealed secret from memory.
  void hideAndZeroizeRevealedSecret() {
    _revealCountdownTimer?.cancel();
    _revealCountdownTimer = null;
    _activeRevealedSecret = null;
    _revealSecondsRemaining = 0;
    notifyListeners();
  }

  /// Creates a new Topic + Secret Text record in the active vault.
  Future<VaultTopicSummary> createTopic({
    required String topic,
    required String secretText,
  }) async {
    final created = await _vaultRepository.saveTopic(
      topic: topic,
      secretText: secretText,
    );
    await loadVaultSummaries();
    return created;
  }

  String generateRandomPassword({int length = 20}) {
    return _vaultRepository.generateStrongPassword(length: length);
  }

  /// Exports a single item into an encrypted `.sxsi` (`"SXSI"`) packet with a File Password.
  Future<String> exportSingleItemSxsi({
    required String itemUuid,
    required String filePassword,
  }) {
    return _vaultRepository.exportSingleItemSxsi(
      itemUuid: itemUuid,
      filePassword: filePassword,
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

  @override
  void dispose() {
    _revealCountdownTimer?.cancel();
    _clipboardCountdownTimer?.cancel();
    super.dispose();
  }
}


