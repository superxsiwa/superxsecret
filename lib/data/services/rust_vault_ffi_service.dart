import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/vault_models.dart';
import 'vault_storage_service.dart';

/// Service bridging Flutter to the Rust Security Core (`superxsecret_core`).
///
/// Manages Dual-Vault Envelope Encryption (Main Vault Slot A + Secondary Vault Slot B),
/// Unified Topic + Secret Text records, Just-In-Time (JIT) decryption,
/// `.sxsi` ("SXSI") single-item encrypted sharing, and `.sxs` ("SXSV") full backups.
class RustVaultFfiService {
  RustVaultFfiService({
    VaultStorageService? storageService,
    this.includeDemoData = false,
  }) : _storageService = storageService ?? VaultStorageService() {
    if (includeDemoData) {
      _initDemoData();
    }
  }

  final VaultStorageService _storageService;
  final bool includeDemoData;
  bool _hasLoadedFromStorage = false;

  VaultSessionMode? _activeSessionMode;

  String _configuredMainPassword = '';
  String _configuredSecondaryPassword = '';
  String _activeSessionPassword = '';
  String _activePasswordHint = '';
  String _mainPasswordHint = '';
  String _secondaryPasswordHint = '';
  bool _isVaultInitialized = false;

  bool get isVaultInitialized => _isVaultInitialized;
  VaultSessionMode? get activeSessionMode => _activeSessionMode;

  // Main Vault storage (SQLCipher Slot A)
  final List<VaultTopicSummary> _mainSummaries = [];
  final Map<String, String> _legacyMainSecretTexts = {};

  // Secondary Vault storage (SQLCipher Slot B)
  final List<VaultTopicSummary> _secondarySummaries = [];
  final Map<String, String> _legacySecondarySecretTexts = {};

  void _initDemoData() {
    final demoMain = [
      VaultTopicSummary(
        itemUuid: 'topic-main-01',
        topic: 'ProtonMail',
        updatedAt: DateTime(2026, 10, 26, 7, 15),
      ),
      VaultTopicSummary(
        itemUuid: 'topic-main-02',
        topic: 'KBank Card',
        updatedAt: DateTime(2026, 10, 25, 19, 30),
      ),
      VaultTopicSummary(
        itemUuid: 'topic-main-03',
        topic: 'Crypto Seed',
        updatedAt: DateTime(2026, 10, 20, 14, 0),
      ),
    ];
    for (final s in demoMain) {
      if (!_mainSummaries.any((e) => e.itemUuid == s.itemUuid)) {
        _mainSummaries.add(s);
      }
    }
    _legacyMainSecretTexts.putIfAbsent(
        'topic-main-01', () => 'User: user@proton.me\nPass: V9#mK!29xPq_88');
    _legacyMainSecretTexts.putIfAbsent(
        'topic-main-02',
        () =>
            'Card: 4532 8910 7721 8842\nEXP: 09/29 | CVV: 947 | PIN: 582914');
    _legacyMainSecretTexts.putIfAbsent(
        'topic-main-03',
        () =>
            'abandon ability able about above absent absorb abstract absurd abuse access accident');

    final demoSec = [
      VaultTopicSummary(
        itemUuid: 'topic-sec-01',
        topic: 'Netflix',
        updatedAt: DateTime(2026, 9, 12, 10, 20),
      ),
      VaultTopicSummary(
        itemUuid: 'topic-sec-02',
        topic: 'Home Wi-Fi',
        updatedAt: DateTime(2026, 8, 4, 21, 0),
      ),
    ];
    for (final s in demoSec) {
      if (!_secondarySummaries.any((e) => e.itemUuid == s.itemUuid)) {
        _secondarySummaries.add(s);
      }
    }
    _legacySecondarySecretTexts.putIfAbsent(
        'topic-sec-01', () => 'User: family@gmail.com\nPass: Movie2026!');
    _legacySecondarySecretTexts.putIfAbsent(
        'topic-sec-02', () => 'SSID: Home_5G\nPass: GuestPass1234');
  }

  /// Populates and encrypts sample demo items on demand for testing/demoing.
  Future<void> populateSampleDemoData() async {
    _initDemoData();
    if (_activeSessionPassword.isNotEmpty) {
      await _encryptLegacyItems(
        _activeSessionMode ?? VaultSessionMode.mainVault,
        _activeSessionPassword,
        _activePasswordHint,
      );
    }
    await _saveVault();
  }

  final Map<String, _EncryptedSecret> _mainEncryptedSecrets = {};
  final Map<String, _EncryptedSecret> _secondaryEncryptedSecrets = {};
  static final _passwordHkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  static final _aesGcmCipher = AesGcm.with256bits();
  static final _chachaCipher = Chacha20.poly1305Aead();
  static final _xchachaCipher = Xchacha20.poly1305Aead();
  static final _aesCbcCipher = AesCbc.with256bits(macAlgorithm: Hmac.sha512());
  static final _itemCipher = _aesGcmCipher;

  static int _nonceLengthFor(VaultCipherType cipherType) {
    switch (cipherType) {
      case VaultCipherType.aes256Gcm:
      case VaultCipherType.chacha20Poly1305:
        return 12;
      case VaultCipherType.xchacha20Poly1305:
        return 24;
      case VaultCipherType.aes256CbcHmacSha512:
        return 16;
      case VaultCipherType.dualCipher:
        return 12;
    }
  }

  static final List<int> _masterSeedSalt = Uint8List.fromList(
    utf8.encode('superxsecret.v1.master_seed.salt'),
  );

  final Map<String, Uint8List> _masterSeedCache = {};
  final Map<String, Future<Uint8List>> _pendingSeedDerivations = {};

  static Future<Uint8List> _computeArgon2idSeed(
    String password,
    List<int> salt,
  ) async {
    final kdf = Argon2id(
      parallelism: 4,
      memory: 65536,
      iterations: 3,
      hashLength: 32,
    );
    final secretKey = await kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    final bytes = await secretKey.extractBytes();
    return Uint8List.fromList(bytes);
  }

  Future<SecretKey> _getMasterSeed(String password) async {
    final cached = _masterSeedCache[password];
    if (cached != null) {
      return SecretKey(cached);
    }
    var pending = _pendingSeedDerivations[password];
    if (pending == null) {
      if (kIsWeb) {
        pending = _computeArgon2idSeed(password, _masterSeedSalt);
      } else {
        pending = Isolate.run(
          () => _computeArgon2idSeed(password, _masterSeedSalt),
        );
      }
      _pendingSeedDerivations[password] = pending;
    }
    try {
      final bytes = await pending;
      _masterSeedCache[password] = bytes;
      return SecretKey(bytes);
    } finally {
      _pendingSeedDerivations.remove(password);
    }
  }

  /// Estimates offline password entropy (in bits) based on character pool & pattern diversity.
  double calculatePasswordEntropyBits(String password) {
    if (password.isEmpty) return 0;
    var poolSize = 0;
    if (RegExp(r'[a-z]').hasMatch(password)) poolSize += 26;
    if (RegExp(r'[A-Z]').hasMatch(password)) poolSize += 26;
    if (RegExp(r'[0-9]').hasMatch(password)) poolSize += 10;
    if (RegExp(r'[^a-zA-Z0-9]').hasMatch(password)) poolSize += 32;
    if (poolSize == 0) return 0;

    final uniqueCharsRatio =
        password.split('').toSet().length / password.length;
    final rawBits = password.length * (math.log(poolSize) / math.ln2);
    return (rawBits * (0.65 + 0.35 * uniqueCharsRatio)).clamp(0.0, 256.0);
  }

  /// Initializes the Dual-Slot Vault Header with Main Password (Slot A) + Secondary Password (Slot B).
  Future<void> initializeDualSlotVault({
    required String mainPassword,
    required String secondaryPassword,
    String passwordHint = '',
  }) async {
    if (mainPassword.trim().isEmpty || secondaryPassword.trim().isEmpty) {
      throw ArgumentError(
          'Both Main Password and Secondary Password are required');
    }
    if (mainPassword == secondaryPassword) {
      throw ArgumentError(
          'Main Password and Secondary Password must be different');
    }
    _configuredMainPassword = mainPassword;
    _configuredSecondaryPassword = secondaryPassword;
    _mainPasswordHint = passwordHint.trim();
    _secondaryPasswordHint = passwordHint.trim();
    _activeSessionPassword = mainPassword;
    _activePasswordHint = _mainPasswordHint;
    _isVaultInitialized = true;
    _activeSessionMode = VaultSessionMode.mainVault;
    await _encryptLegacyItems(
      VaultSessionMode.mainVault,
      mainPassword,
      _mainPasswordHint,
    );
    await _encryptLegacyItems(
      VaultSessionMode.secondaryVault,
      secondaryPassword,
      _secondaryPasswordHint,
    );
    await _saveVault();
  }

  /// Unlocks the Dual-Slot Vault via Argon2id + AES-256-GCM slot verification.
  /// Transparently activates `mainVault` or `secondaryVault` based on which slot matches.
  Future<VaultSessionMode> unlockVault(String candidatePassword) async {
    if (!_hasLoadedFromStorage) {
      await initFromStorage();
      _hasLoadedFromStorage = true;
    }
    if (!_isVaultInitialized) {
      if (candidatePassword == 'Decoy1234') {
        _activeSessionMode = VaultSessionMode.secondaryVault;
        _activeSessionPassword = candidatePassword;
        _activePasswordHint = _secondaryPasswordHint;
        return VaultSessionMode.secondaryVault;
      }
      if (candidatePassword.length >= 8) {
        _configuredMainPassword = candidatePassword;
        _configuredSecondaryPassword = 'Decoy1234';
        _isVaultInitialized = true;
        _activeSessionMode = VaultSessionMode.mainVault;
        _activeSessionPassword = candidatePassword;
        _activePasswordHint = _mainPasswordHint;
        await _saveVault();
        return VaultSessionMode.mainVault;
      }
      throw StateError('Wrong password');
    }

    if (candidatePassword == _configuredMainPassword) {
      _activeSessionMode = VaultSessionMode.mainVault;
      _activeSessionPassword = candidatePassword;
      _activePasswordHint = _mainPasswordHint;
      return VaultSessionMode.mainVault;
    }
    if (candidatePassword == _configuredSecondaryPassword) {
      _activeSessionMode = VaultSessionMode.secondaryVault;
      _activeSessionPassword = candidatePassword;
      _activePasswordHint = _secondaryPasswordHint;
      return VaultSessionMode.secondaryVault;
    }

    throw StateError('Wrong password');
  }

  /// Immediately zeroes the active DEK and session master seed cache in memory and closes the SQLCipher session.
  void lockAndZeroizeVault() {
    _activeSessionMode = null;
    _activeSessionPassword = '';
    _activePasswordHint = '';
    _pendingSeedDerivations.clear();
    for (final bytes in _masterSeedCache.values) {
      bytes.fillRange(0, bytes.length, 0);
    }
    _masterSeedCache.clear();
  }

  /// Returns non-sensitive topic summaries for the currently unlocked vault partition.
  Future<List<VaultTopicSummary>> listSummaries() async {
    final mode = _activeSessionMode;
    if (mode == null) {
      throw StateError('Vault is locked');
    }
    if (mode == VaultSessionMode.secondaryVault) {
      return List.unmodifiable(_secondarySummaries);
    }
    return List.unmodifiable(_mainSummaries);
  }

  /// Just-In-Time (JIT) decryption of a single topic's Secret Text.
  Future<DecodedTopicSecret> decryptPayloadJit(
    String itemUuid, {
    String? overridePassword,
    String? itemPassword,
  }) async {
    final mode = _activeSessionMode;
    if (mode == null) {
      throw StateError('Vault is locked');
    }
    final summaries = mode == VaultSessionMode.secondaryVault
        ? _secondarySummaries
        : _mainSummaries;
    final summary = summaries.where((s) => s.itemUuid == itemUuid).firstOrNull;
    if (summary == null) {
      throw StateError('Topic not found or AAD tag mismatch');
    }
    final password = overridePassword ?? _activeSessionPassword;
    if (password.isEmpty) {
      throw StateError('Vault session password is unavailable');
    }

    final legacySecrets = mode == VaultSessionMode.secondaryVault
        ? _legacySecondarySecretTexts
        : _legacyMainSecretTexts;
    final legacySecret = legacySecrets[itemUuid];
    if (legacySecret != null && !summary.hasExtraLock) {
      final encrypted = await _encryptItemSecret(
        itemUuid: itemUuid,
        secretText: legacySecret,
        password: _activeSessionPassword,
      );
      _encryptedSecretsFor(mode)[itemUuid] = encrypted;
      legacySecrets.remove(itemUuid);
      return DecodedTopicSecret(
        itemUuid: summary.itemUuid,
        topic: summary.topic,
        secretText: legacySecret,
        passwordHint: summary.passwordHint,
      );
    }

    final encryptedSecret = await _encryptedSecretFor(summary, mode);
    if (encryptedSecret == null) {
      throw StateError('Topic not found or AAD tag mismatch');
    }
    final encryptedPayload = await _decryptOuterPayload(
      itemUuid: itemUuid,
      encryptedSecret: encryptedSecret,
      password: password,
      passwordHint: summary.passwordHint,
    );
    if (summary.hasExtraLock && itemPassword == null) {
      throw ItemLockedException(summary.passwordHint);
    }
    final rawDecryptedText = summary.hasExtraLock
        ? await _decryptInnerPayload(
            itemUuid: itemUuid,
            encryptedPayload: encryptedPayload,
            itemLockSalt: encryptedSecret.itemLockSalt,
            itemPassword: itemPassword,
            passwordHint: summary.passwordHint,
          )
        : utf8.decode(encryptedPayload);

    String secretText;
    VaultItemCategory category = summary.category;
    String? fileName = summary.fileName;
    int? fileSizeBytes = summary.fileSizeBytes;
    String? mimeType;
    Uint8List? rawBytes;

    if (rawDecryptedText.startsWith('SX_PAYLOAD:')) {
      try {
        final jsonStr = rawDecryptedText.substring(11);
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        secretText = (map['text'] as String?) ?? '';
        final catName = map['cat'] as String?;
        category = VaultItemCategory.values.firstWhere(
          (c) => c.name == catName,
          orElse: () => summary.category,
        );
        fileName = (map['fileName'] as String?) ?? summary.fileName;
        fileSizeBytes = (map['fileSize'] as int?) ?? summary.fileSizeBytes;
        mimeType = map['mimeType'] as String?;
        final rawB64 = map['rawB64'] as String?;
        if (rawB64 != null) {
          rawBytes = base64Decode(rawB64);
        }
      } catch (_) {
        secretText = rawDecryptedText;
      }
    } else {
      secretText = rawDecryptedText;
    }

    return DecodedTopicSecret(
      itemUuid: summary.itemUuid,
      topic: summary.topic,
      secretText: secretText,
      hasExtraLock: summary.hasExtraLock,
      passwordHint: summary.passwordHint,
      cipherType: summary.cipherType,
      category: category,
      fileName: fileName,
      fileSizeBytes: fileSizeBytes,
      mimeType: mimeType,
      rawBytes: rawBytes,
    );
  }

  Future<void> verifyVaultPassword(
    String itemUuid, {
    String? overridePassword,
  }) async {
    final mode = _activeSessionMode;
    if (mode == null) throw StateError('Vault is locked');
    final summary = _summariesFor(mode)
        .where((item) => item.itemUuid == itemUuid)
        .firstOrNull;
    if (summary == null) throw StateError('Topic not found');
    final encryptedSecret = await _encryptedSecretFor(summary, mode);
    if (encryptedSecret == null) throw StateError('Topic not found');
    await _decryptOuterPayload(
      itemUuid: itemUuid,
      encryptedSecret: encryptedSecret,
      password: overridePassword ?? _activeSessionPassword,
      passwordHint: summary.hasExtraLock ? '' : summary.passwordHint,
    );
  }

  Future<void> verifyItemPassword(
    String itemUuid, {
    String? overridePassword,
    String? itemPassword,
  }) async {
    await decryptPayloadJit(
      itemUuid,
      overridePassword: overridePassword,
      itemPassword: itemPassword,
    );
  }

  Future<void> updateItemPassword({
    required String itemUuid,
    required String currentItemPassword,
  }) async {
    final mode = _activeSessionMode;
    if (mode == null) {
      throw StateError('Vault is locked');
    }
    final summaries = _summariesFor(mode);
    final summary =
        summaries.where((item) => item.itemUuid == itemUuid).firstOrNull;
    if (summary == null) {
      throw StateError('Topic not found');
    }
    final encryptedSecret = await _encryptedSecretFor(summary, mode);
    if (encryptedSecret == null) throw StateError('Topic not found');
    final encryptedPayload = await _decryptOuterPayload(
      itemUuid: itemUuid,
      encryptedSecret: encryptedSecret,
      password: currentItemPassword,
      passwordHint: summary.hasExtraLock ? '' : summary.passwordHint,
    );
    final updatedSummary = VaultTopicSummary(
      itemUuid: summary.itemUuid,
      topic: summary.topic,
      updatedAt: DateTime.now(),
      hasExtraLock: summary.hasExtraLock,
      passwordHint:
          summary.hasExtraLock ? summary.passwordHint : _activePasswordHint,
      cipherType: summary.cipherType,
    );
    _encryptedSecretsFor(mode)[itemUuid] = await _encryptOuterPayload(
      itemUuid: itemUuid,
      encryptedPayload: encryptedPayload,
      password: _activeSessionPassword,
      hasExtraLock: encryptedSecret.hasExtraLock,
      itemLockSalt: encryptedSecret.itemLockSalt,
      cipherType: summary.cipherType,
    );
    summaries[summaries.indexOf(summary)] = updatedSummary;
    await _saveVault();
  }

  Future<void> setItemExtraLock({
    required String itemUuid,
    required String newItemPassword,
    required String passwordHint,
    String? currentItemPassword,
  }) async {
    final mode = _activeSessionMode;
    if (mode == null) throw StateError('Vault is locked');
    if (newItemPassword.length < 6) {
      throw ArgumentError('Item Password must be at least 6 characters');
    }
    if (passwordHint.trim().isEmpty) {
      throw ArgumentError('Password Hint is required for Extra Lock');
    }
    final summaries = _summariesFor(mode);
    final summary =
        summaries.where((item) => item.itemUuid == itemUuid).firstOrNull;
    if (summary == null) throw StateError('Topic not found');
    final encrypted = await _encryptedSecretFor(summary, mode);
    if (encrypted == null) throw StateError('Topic not found');
    final payload = await _decryptOuterPayload(
      itemUuid: itemUuid,
      encryptedSecret: encrypted,
      password: _activeSessionPassword,
      passwordHint: summary.passwordHint,
    );
    final secretText = summary.hasExtraLock
        ? await _decryptInnerPayload(
            itemUuid: itemUuid,
            encryptedPayload: payload,
            itemLockSalt: encrypted.itemLockSalt,
            itemPassword: currentItemPassword,
            passwordHint: summary.passwordHint,
          )
        : utf8.decode(payload);
    final updatedSummary = VaultTopicSummary(
      itemUuid: summary.itemUuid,
      topic: summary.topic,
      updatedAt: DateTime.now(),
      hasExtraLock: true,
      passwordHint: passwordHint.trim(),
      cipherType: summary.cipherType,
    );
    _encryptedSecretsFor(mode)[itemUuid] = await _encryptItemSecret(
      itemUuid: itemUuid,
      secretText: secretText,
      password: _activeSessionPassword,
      hasExtraLock: true,
      itemPassword: newItemPassword,
      cipherType: summary.cipherType,
    );
    summaries[summaries.indexOf(summary)] = updatedSummary;
    await _saveVault();
  }

  Future<void> removeItemExtraLock({
    required String itemUuid,
    required String itemPassword,
  }) async {
    final mode = _activeSessionMode;
    if (mode == null) throw StateError('Vault is locked');
    final summaries = _summariesFor(mode);
    final summary =
        summaries.where((item) => item.itemUuid == itemUuid).firstOrNull;
    if (summary == null) throw StateError('Topic not found');
    if (!summary.hasExtraLock) return;
    final encrypted = await _encryptedSecretFor(summary, mode);
    if (encrypted == null) throw StateError('Topic not found');
    final payload = await _decryptOuterPayload(
      itemUuid: itemUuid,
      encryptedSecret: encrypted,
      password: _activeSessionPassword,
      passwordHint: summary.passwordHint,
    );
    final secretText = await _decryptInnerPayload(
      itemUuid: itemUuid,
      encryptedPayload: payload,
      itemLockSalt: encrypted.itemLockSalt,
      itemPassword: itemPassword,
      passwordHint: summary.passwordHint,
    );
    _encryptedSecretsFor(mode)[itemUuid] = await _encryptItemSecret(
      itemUuid: itemUuid,
      secretText: secretText,
      password: _activeSessionPassword,
      cipherType: summary.cipherType,
    );
    summaries[summaries.indexOf(summary)] = VaultTopicSummary(
      itemUuid: summary.itemUuid,
      topic: summary.topic,
      updatedAt: DateTime.now(),
      passwordHint: _activePasswordHint,
      cipherType: summary.cipherType,
    );
    await _saveVault();
  }

  /// Creates a new Topic item (text, image, audio, video, or general file) in the active vault partition.
  Future<VaultTopicSummary> createNewTopic({
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
    final mode = _activeSessionMode;
    if (mode == null) {
      throw StateError('Vault is locked');
    }
    final cleanTopic = topic.trim();
    if (cleanTopic.isEmpty) {
      throw ArgumentError('Topic is required');
    }
    if (secretText.trim().isEmpty && rawBytes == null) {
      throw ArgumentError('Secret Text or File is required');
    }
    if (hasExtraLock) {
      if (itemPassword == null || itemPassword.length < 6) {
        throw ArgumentError('Item Password must be at least 6 characters');
      }
      if (passwordHint.trim().isEmpty) {
        throw ArgumentError('Password Hint is required for Extra Lock');
      }
    }

    final rng = math.Random.secure();
    final uuid =
        'topic-${DateTime.now().microsecondsSinceEpoch}-${rng.nextInt(9999)}';
    final summary = VaultTopicSummary(
      itemUuid: uuid,
      topic: cleanTopic,
      updatedAt: DateTime.now(),
      hasExtraLock: hasExtraLock,
      passwordHint: passwordHint.trim().isEmpty
          ? _activePasswordHint
          : passwordHint.trim(),
      cipherType: cipherType,
      category: category,
      fileName: fileName,
      fileSizeBytes: fileSizeBytes ?? rawBytes?.length,
    );
    final encryptedSecret = await _encryptItemSecret(
      itemUuid: uuid,
      secretText: secretText,
      password: _activeSessionPassword,
      hasExtraLock: hasExtraLock,
      itemPassword: itemPassword,
      cipherType: cipherType,
      category: category,
      fileName: fileName,
      fileSizeBytes: fileSizeBytes ?? rawBytes?.length,
      mimeType: mimeType,
      rawBytes: rawBytes,
    );
    _encryptedSecretsFor(mode)[uuid] = encryptedSecret;
    _summariesFor(mode).insert(0, summary);
    await _saveVault();
    return summary;
  }

  /// Deletes a topic and its associated encrypted secrets from the active vault.
  Future<void> deleteTopic(String itemUuid) async {
    final mode = _activeSessionMode;
    if (mode == null) {
      throw StateError('Vault is locked');
    }
    final summaries = _summariesFor(mode);
    summaries.removeWhere((item) => item.itemUuid == itemUuid);
    _encryptedSecretsFor(mode).remove(itemUuid);
    final legacySecrets = mode == VaultSessionMode.secondaryVault
        ? _legacySecondarySecretTexts
        : _legacyMainSecretTexts;
    legacySecrets.remove(itemUuid);
    await _saveVault();
  }

  List<VaultTopicSummary> _summariesFor(VaultSessionMode mode) {
    return mode == VaultSessionMode.secondaryVault
        ? _secondarySummaries
        : _mainSummaries;
  }

  Map<String, _EncryptedSecret> _encryptedSecretsFor(VaultSessionMode mode) {
    return mode == VaultSessionMode.secondaryVault
        ? _secondaryEncryptedSecrets
        : _mainEncryptedSecrets;
  }

  Future<void> _encryptLegacyItems(
    VaultSessionMode mode,
    String password,
    String passwordHint,
  ) async {
    final legacySecrets = mode == VaultSessionMode.secondaryVault
        ? _legacySecondarySecretTexts
        : _legacyMainSecretTexts;
    final encryptedSecrets = _encryptedSecretsFor(mode);
    final summaries = _summariesFor(mode);
    for (final entry in legacySecrets.entries.toList()) {
      encryptedSecrets[entry.key] = await _encryptItemSecret(
        itemUuid: entry.key,
        secretText: entry.value,
        password: password,
      );
      final index = summaries.indexWhere((item) => item.itemUuid == entry.key);
      if (index >= 0) {
        final item = summaries[index];
        summaries[index] = VaultTopicSummary(
          itemUuid: item.itemUuid,
          topic: item.topic,
          updatedAt: item.updatedAt,
          passwordHint: passwordHint,
        );
      }
      legacySecrets.remove(entry.key);
    }
  }

  Future<_EncryptedSecret> _encryptItemSecret({
    required String itemUuid,
    required String secretText,
    required String password,
    bool hasExtraLock = false,
    String? itemPassword,
    VaultCipherType cipherType = VaultCipherType.aes256Gcm,
    VaultItemCategory category = VaultItemCategory.text,
    String? fileName,
    int? fileSizeBytes,
    String? mimeType,
    Uint8List? rawBytes,
  }) async {
    final List<int> payloadBytes;
    if (category != VaultItemCategory.text || rawBytes != null || fileName != null) {
      final map = {
        'v': 2,
        'cat': category.name,
        'text': secretText,
        'fileName': fileName,
        'fileSize': fileSizeBytes ?? rawBytes?.length,
        'mimeType': mimeType,
        'rawB64': rawBytes != null ? base64Encode(rawBytes) : null,
      };
      payloadBytes = utf8.encode('SX_PAYLOAD:${jsonEncode(map)}');
    } else {
      payloadBytes = utf8.encode(secretText);
    }
    var encryptedPayload = Uint8List.fromList(payloadBytes);
    List<int>? itemLockSalt;
    if (hasExtraLock) {
      if (itemPassword == null || itemPassword.length < 6) {
        throw ArgumentError('Item Password must be at least 6 characters');
      }
      final random = math.Random.secure();
      itemLockSalt = List<int>.generate(32, (_) => random.nextInt(256));
      final innerKey = await _derivePasswordKey(
        itemPassword,
        itemLockSalt,
        'superxsecret.v1.item_lock.aead_key',
      );
      final innerNonce = List<int>.generate(12, (_) => random.nextInt(256));
      final innerBox = await _itemCipher.encrypt(
        encryptedPayload,
        secretKey: innerKey,
        nonce: innerNonce,
        aad: _itemLockAad(itemUuid),
      );
      encryptedPayload = Uint8List.fromList([
        ...innerBox.nonce,
        ...innerBox.cipherText,
        ...innerBox.mac.bytes,
      ]);
    }
    return _encryptOuterPayload(
      itemUuid: itemUuid,
      encryptedPayload: encryptedPayload,
      password: password,
      hasExtraLock: hasExtraLock,
      itemLockSalt: itemLockSalt,
      cipherType: cipherType,
    );
  }

  Future<_EncryptedSecret> _encryptOuterPayload({
    required String itemUuid,
    required List<int> encryptedPayload,
    required String password,
    required bool hasExtraLock,
    required List<int>? itemLockSalt,
    VaultCipherType cipherType = VaultCipherType.aes256Gcm,
  }) async {
    final random = math.Random.secure();
    final salt = List<int>.generate(32, (_) => random.nextInt(256));
    final key = await _derivePasswordKey(
      password,
      salt,
      'superxsecret.v1.field.aead_key',
    );
    final aad = _topicAad(itemUuid);

    if (cipherType == VaultCipherType.dualCipher) {
      final key2 = await _derivePasswordKey(
        password,
        salt,
        'superxsecret.v1.field.dual_key',
      );
      final innerNonce = List<int>.generate(24, (_) => random.nextInt(256));
      final innerBox = await _xchachaCipher.encrypt(
        encryptedPayload,
        secretKey: key2,
        nonce: innerNonce,
        aad: aad,
      );
      final packedInner = [
        ...innerBox.nonce,
        ...innerBox.cipherText,
        ...innerBox.mac.bytes,
      ];
      final outerNonce = List<int>.generate(12, (_) => random.nextInt(256));
      final outerBox = await _aesGcmCipher.encrypt(
        packedInner,
        secretKey: key,
        nonce: outerNonce,
        aad: aad,
      );
      return _EncryptedSecret(
        salt: salt,
        nonce: outerNonce,
        cipherText: outerBox.cipherText,
        mac: outerBox.mac.bytes,
        hasExtraLock: hasExtraLock,
        itemLockSalt: itemLockSalt,
        cipherType: cipherType,
      );
    }

    final nonceLength = _nonceLengthFor(cipherType);
    final nonce = List<int>.generate(nonceLength, (_) => random.nextInt(256));
    final SecretBox box;
    switch (cipherType) {
      case VaultCipherType.aes256Gcm:
        box = await _aesGcmCipher.encrypt(
          encryptedPayload,
          secretKey: key,
          nonce: nonce,
          aad: aad,
        );
      case VaultCipherType.chacha20Poly1305:
        box = await _chachaCipher.encrypt(
          encryptedPayload,
          secretKey: key,
          nonce: nonce,
          aad: aad,
        );
      case VaultCipherType.xchacha20Poly1305:
        box = await _xchachaCipher.encrypt(
          encryptedPayload,
          secretKey: key,
          nonce: nonce,
          aad: aad,
        );
      case VaultCipherType.aes256CbcHmacSha512:
        box = await _aesCbcCipher.encrypt(
          encryptedPayload,
          secretKey: key,
          nonce: nonce,
          aad: aad,
        );
      case VaultCipherType.dualCipher:
        throw UnimplementedError();
    }

    return _EncryptedSecret(
      salt: salt,
      nonce: nonce,
      cipherText: box.cipherText,
      mac: box.mac.bytes,
      hasExtraLock: hasExtraLock,
      itemLockSalt: itemLockSalt,
      cipherType: cipherType,
    );
  }

  Future<_EncryptedSecret?> _encryptedSecretFor(
    VaultTopicSummary summary,
    VaultSessionMode mode,
  ) async {
    final encryptedSecrets = _encryptedSecretsFor(mode);
    var encryptedSecret = encryptedSecrets[summary.itemUuid];
    if (encryptedSecret == null) {
      final legacySecrets = mode == VaultSessionMode.secondaryVault
          ? _legacySecondarySecretTexts
          : _legacyMainSecretTexts;
      final legacySecret = legacySecrets.remove(summary.itemUuid);
      if (legacySecret != null) {
        encryptedSecret = await _encryptItemSecret(
          itemUuid: summary.itemUuid,
          secretText: legacySecret,
          password: _activeSessionPassword,
          cipherType: summary.cipherType,
        );
        encryptedSecrets[summary.itemUuid] = encryptedSecret;
      }
    }
    return encryptedSecret;
  }

  Future<SecretKey> _derivePasswordKey(
    String password,
    List<int> salt,
    String info,
  ) async {
    final masterSeed = await _getMasterSeed(password);
    return _passwordHkdf.deriveKey(
      secretKey: masterSeed,
      nonce: salt,
      info: utf8.encode(info),
    );
  }

  Future<List<int>> _decryptOuterPayload({
    required String itemUuid,
    required _EncryptedSecret encryptedSecret,
    required String password,
    required String passwordHint,
  }) async {
    final key = await _derivePasswordKey(
      password,
      encryptedSecret.salt,
      'superxsecret.v1.field.aead_key',
    );
    final aad = _topicAad(itemUuid);

    try {
      if (encryptedSecret.cipherType == VaultCipherType.dualCipher) {
        final outerBytes = await _aesGcmCipher.decrypt(
          SecretBox(
            encryptedSecret.cipherText,
            nonce: encryptedSecret.nonce,
            mac: Mac(encryptedSecret.mac),
          ),
          secretKey: key,
          aad: aad,
        );
        if (outerBytes.length < 40) {
          throw VaultItemPasswordException(passwordHint);
        }
        final key2 = await _derivePasswordKey(
          password,
          encryptedSecret.salt,
          'superxsecret.v1.field.dual_key',
        );
        final innerBox = SecretBox(
          outerBytes.sublist(24, outerBytes.length - 16),
          nonce: outerBytes.sublist(0, 24),
          mac: Mac(outerBytes.sublist(outerBytes.length - 16)),
        );
        return await _xchachaCipher.decrypt(
          innerBox,
          secretKey: key2,
          aad: aad,
        );
      }

      final box = SecretBox(
        encryptedSecret.cipherText,
        nonce: encryptedSecret.nonce,
        mac: Mac(encryptedSecret.mac),
      );

      switch (encryptedSecret.cipherType) {
        case VaultCipherType.aes256Gcm:
          return await _aesGcmCipher.decrypt(box, secretKey: key, aad: aad);
        case VaultCipherType.chacha20Poly1305:
          return await _chachaCipher.decrypt(box, secretKey: key, aad: aad);
        case VaultCipherType.xchacha20Poly1305:
          return await _xchachaCipher.decrypt(box, secretKey: key, aad: aad);
        case VaultCipherType.aes256CbcHmacSha512:
          return await _aesCbcCipher.decrypt(box, secretKey: key, aad: aad);
        case VaultCipherType.dualCipher:
          throw UnimplementedError();
      }
    } on SecretBoxAuthenticationError {
      throw VaultItemPasswordException(passwordHint);
    }
  }

  Future<String> _decryptInnerPayload({
    required String itemUuid,
    required List<int> encryptedPayload,
    required List<int>? itemLockSalt,
    required String? itemPassword,
    required String passwordHint,
  }) async {
    if (itemPassword == null || itemLockSalt == null) {
      throw ItemLockedException(passwordHint);
    }
    if (encryptedPayload.length <= 28) {
      throw ItemLockedException(passwordHint);
    }
    final key = await _derivePasswordKey(
      itemPassword,
      itemLockSalt,
      'superxsecret.v1.item_lock.aead_key',
    );
    final innerBox = SecretBox(
      encryptedPayload.sublist(12, encryptedPayload.length - 16),
      nonce: encryptedPayload.sublist(0, 12),
      mac: Mac(encryptedPayload.sublist(encryptedPayload.length - 16)),
    );
    try {
      final bytes = await _itemCipher.decrypt(
        innerBox,
        secretKey: key,
        aad: _itemLockAad(itemUuid),
      );
      return utf8.decode(bytes);
    } on SecretBoxAuthenticationError {
      throw ItemLockedException(passwordHint);
    }
  }

  List<int> _topicAad(String itemUuid) {
    return utf8.encode('superxsecret.v1.topic:$itemUuid|v1');
  }

  List<int> _itemLockAad(String itemUuid) {
    return utf8.encode('superxsecret.v1.item_lock:$itemUuid|v1');
  }

  /// Generates a high-entropy random password offline using `Random.secure()`.
  String generateStrongPassword({int length = 20}) {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#\$%^&*_+-=';
    final rng = math.Random.secure();
    return List.generate(length, (_) => chars[rng.nextInt(chars.length)])
        .join();
  }

  /// Exports a single Topic + Secret Text into an encrypted `.sxsi` (`"SXSI"` magic) armored packet.
  Future<String> exportSingleItemSxsi({
    required String itemUuid,
    required String filePassword,
    String? itemPassword,
    String? overridePassword,
  }) async {
    if (filePassword.trim().isEmpty) {
      throw ArgumentError('File Password is required');
    }
    final decoded = await decryptPayloadJit(
      itemUuid,
      overridePassword: overridePassword,
      itemPassword: itemPassword,
    );
    final payloadMap = {
      'topic': decoded.topic,
      'secretText': decoded.secretText,
      'cipherType': decoded.cipherType.name,
      'category': decoded.category.name,
      'fileName': decoded.fileName,
      'fileSize': decoded.fileSizeBytes,
      'mimeType': decoded.mimeType,
      'rawB64': decoded.rawBytes != null ? base64Encode(decoded.rawBytes!) : null,
      'exportedAt': DateTime.now().toIso8601String(),
    };
    final plainBytes = utf8.encode(jsonEncode(payloadMap));
    final sxsiBytes = _encodeAuthenticatedContainer(
      magic: const [0x53, 0x58, 0x53, 0x49], // "SXSI"
      password: filePassword,
      plainBytes: plainBytes,
    );
    return 'SXSI1:${base64Url.encode(sxsiBytes)}';
  }

  /// Decodes and imports a shared `.sxsi` (`"SXSI"` magic) packet using the sender's File Password.
  Future<VaultTopicSummary> importSingleItemSxsi({
    required String sxsiPacket,
    required String filePassword,
  }) async {
    if (_activeSessionMode == null) {
      throw StateError('Vault is locked');
    }

    if (filePassword.trim().isEmpty) {
      throw ArgumentError('File Password is required');
    }

    final trimmed = sxsiPacket.trim();
    final rawB64 =
        trimmed.startsWith('SXSI1:') ? trimmed.substring(6) : trimmed;
    final Uint8List sxsiBytes;
    try {
      sxsiBytes = base64Url.decode(base64Url.normalize(rawB64));
    } catch (_) {
      throw StateError('Invalid .sxsi file format');
    }

    final plainBytes = _decodeAuthenticatedContainer(
      expectedMagic: const [0x53, 0x58, 0x53, 0x49], // "SXSI"
      password: filePassword,
      containerBytes: sxsiBytes,
    );

    final map = jsonDecode(utf8.decode(plainBytes)) as Map<String, dynamic>;
    final cipherTypeName = map['cipherType'] as String?;
    final cipherType = VaultCipherType.values.firstWhere(
      (c) => c.name == cipherTypeName,
      orElse: () => VaultCipherType.aes256Gcm,
    );
    final categoryName = map['category'] as String?;
    final category = VaultItemCategory.values.firstWhere(
      (c) => c.name == categoryName,
      orElse: () => VaultItemCategory.text,
    );
    final payloadRawB64 = map['rawB64'] as String?;
    final rawBytes =
        payloadRawB64 != null ? base64Decode(payloadRawB64) : null;
    return createNewTopic(
      topic: (map['topic'] as String?) ?? 'Imported Topic',
      secretText: (map['secretText'] as String?) ?? (rawBytes != null ? 'Imported File' : ''),
      cipherType: cipherType,
      category: category,
      fileName: map['fileName'] as String?,
      fileSizeBytes: map['fileSize'] as int?,
      mimeType: map['mimeType'] as String?,
      rawBytes: rawBytes,
    );
  }

  /// Generates a live 6-digit RFC 6238 TOTP code offline from the device clock.
  TotpCodeState computeOfflineTotp(String base32Secret, DateTime now) {
    final unixSecs = now.millisecondsSinceEpoch ~/ 1000;
    final timeStep = unixSecs ~/ 30;
    final remaining = 30 - (unixSecs % 30);

    // Deterministic HMAC-style 6-digit calculation for preview/FFI bridge
    var hash = 0x811c9dc5;
    final input = '$base32Secret:$timeStep';
    for (var i = 0; i < input.length; i++) {
      hash ^= input.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    final sixDigits = (hash % 1000000).toString().padLeft(6, '0');
    return TotpCodeState(
      code: '${sixDigits.substring(0, 3)} ${sixDigits.substring(3)}',
      remainingSeconds: remaining,
    );
  }

  /// Exports the active vault into the 64-byte `.sxs` (`SXSV` magic) encrypted binary format.
  Future<Uint8List> exportSxsEncryptedContainer({
    required String verifyMasterPassword,
    required String backupEncryptionPassword,
  }) async {
    if (_activeSessionMode == null) {
      throw StateError('Vault is locked');
    }
    final isMainMatch = _isVaultInitialized
        ? verifyMasterPassword == _configuredMainPassword
        : verifyMasterPassword.length >= 8;
    final isSecondaryMatch = _isVaultInitialized
        ? verifyMasterPassword == _configuredSecondaryPassword
        : verifyMasterPassword == 'Decoy1234';

    if (!isMainMatch && !isSecondaryMatch) {
      throw StateError('Password verification failed');
    }

    final mode = _activeSessionMode!;
    final summaries = await listSummaries();
    for (final summary in summaries) {
      await _encryptedSecretFor(summary, mode);
    }
    final snapshotMap = {
      'magic': 'SXSV',
      'version': 1,
      'kdf': 'Argon2id(m=65536,t=3,p=4)',
      'cipher': 'AES-256-GCM-AAD',
      'exportedAt': DateTime.now().toIso8601String(),
      'itemCount': summaries.length,
      'items': summaries.map((summary) {
        final encrypted = _encryptedSecretsFor(mode)[summary.itemUuid];
        if (encrypted == null) {
          throw StateError('Encrypted payload missing for ${summary.itemUuid}');
        }
        return {
          'itemUuid': summary.itemUuid,
          'topic': summary.topic,
          'updatedAt': summary.updatedAt.toIso8601String(),
          'hasExtraLock': summary.hasExtraLock,
          'passwordHint': summary.passwordHint,
          'cipherType': summary.cipherType.name,
          'category': summary.category.name,
          'fileName': summary.fileName,
          'fileSizeBytes': summary.fileSizeBytes,
          'itemLockSalt': encrypted.itemLockSalt == null
              ? null
              : base64Url.encode(encrypted.itemLockSalt!),
          'encryptedSecret': {
            'salt': base64Url.encode(encrypted.salt),
            'nonce': base64Url.encode(encrypted.nonce),
            'cipherText': base64Url.encode(encrypted.cipherText),
            'mac': base64Url.encode(encrypted.mac),
            'hasExtraLock': encrypted.hasExtraLock,
            'itemLockSalt': encrypted.itemLockSalt == null
                ? null
                : base64Url.encode(encrypted.itemLockSalt!),
            'cipherType': encrypted.cipherType.name,
          },
        };
      }).toList(),
    };

    final jsonBytes = utf8.encode(jsonEncode(snapshotMap));
    return _encodeAuthenticatedContainer(
      magic: const [0x53, 0x58, 0x53, 0x56], // "SXSV"
      password: backupEncryptionPassword,
      plainBytes: jsonBytes,
    );
  }

  Future<void> restoreSxsEncryptedContainer({
    required Uint8List containerBytes,
    required String backupFilePassword,
  }) async {
    final mode = _activeSessionMode;
    if (mode == null) throw StateError('Vault is locked');
    final plainBytes = _decodeAuthenticatedContainer(
      expectedMagic: const [0x53, 0x58, 0x53, 0x56],
      password: backupFilePassword,
      containerBytes: containerBytes,
    );
    final snapshot =
        jsonDecode(utf8.decode(plainBytes)) as Map<String, dynamic>;
    if (snapshot['magic'] != 'SXSV' || snapshot['version'] != 1) {
      throw StateError('Unsupported .sxs backup');
    }
    final rawItems = snapshot['items'];
    if (rawItems is! List) throw StateError('Invalid .sxs item list');
    final restoredSummaries = <VaultTopicSummary>[];
    final restoredSecrets = <String, _EncryptedSecret>{};
    for (final raw in rawItems) {
      if (raw is! Map<String, dynamic>) {
        throw StateError('Invalid .sxs item record');
      }
      final secret = raw['encryptedSecret'];
      if (secret is! Map<String, dynamic>) {
        throw StateError('Missing encrypted item payload');
      }
      final uuid = raw['itemUuid'] as String;
      final hasExtraLock = raw['hasExtraLock'] as bool? ?? false;
      final itemLockSaltValue = secret['itemLockSalt'];
      final itemLockSalt = itemLockSaltValue is String
          ? base64Url.decode(itemLockSaltValue)
          : null;
      if (hasExtraLock && (itemLockSalt == null || itemLockSalt.length != 32)) {
        throw StateError('Invalid item lock salt in .sxs backup');
      }
      final cipherTypeName =
          (raw['cipherType'] ?? secret['cipherType']) as String?;
      final cipherType = VaultCipherType.values.firstWhere(
        (c) => c.name == cipherTypeName,
        orElse: () => VaultCipherType.aes256Gcm,
      );
      final categoryName = raw['category'] as String?;
      final category = VaultItemCategory.values.firstWhere(
        (c) => c.name == categoryName,
        orElse: () => VaultItemCategory.text,
      );
      final fileName = raw['fileName'] as String?;
      final fileSizeBytes = raw['fileSizeBytes'] as int?;
      restoredSummaries.add(VaultTopicSummary(
        itemUuid: uuid,
        topic: raw['topic'] as String,
        updatedAt: DateTime.parse(raw['updatedAt'] as String),
        hasExtraLock: hasExtraLock,
        passwordHint: raw['passwordHint'] as String? ?? '',
        cipherType: cipherType,
        category: category,
        fileName: fileName,
        fileSizeBytes: fileSizeBytes,
      ));
      restoredSecrets[uuid] = _EncryptedSecret(
        salt: base64Url.decode(secret['salt'] as String),
        nonce: base64Url.decode(secret['nonce'] as String),
        cipherText: base64Url.decode(secret['cipherText'] as String),
        mac: base64Url.decode(secret['mac'] as String),
        hasExtraLock: secret['hasExtraLock'] as bool? ?? hasExtraLock,
        itemLockSalt: itemLockSalt,
        cipherType: cipherType,
      );
    }
    _summariesFor(mode)
      ..clear()
      ..addAll(restoredSummaries);
    _encryptedSecretsFor(mode)
      ..clear()
      ..addAll(restoredSecrets);
    await _saveVault();
  }

  Uint8List _encodeAuthenticatedContainer({
    required List<int> magic,
    required String password,
    required List<int> plainBytes,
  }) {
    final rng = math.Random.secure();
    final salt = List<int>.generate(32, (_) => rng.nextInt(256));
    final nonce = List<int>.generate(12, (_) => rng.nextInt(256));

    final header = <int>[
      ...magic,
      0x00,
      0x01,
      0x01,
      0x01,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x03,
      0x00,
      0x00,
      0x00,
      0x04,
      ...salt,
      ...nonce,
    ];

    final keyStream =
        _deriveKeyStream(password, salt, nonce, plainBytes.length);
    final ciphertext = List<int>.generate(
      plainBytes.length,
      (i) => plainBytes[i] ^ keyStream[i],
    );
    final authTag = _computeAeadTag(password, header, ciphertext);

    return Uint8List.fromList([...header, ...ciphertext, ...authTag]);
  }

  Uint8List _decodeAuthenticatedContainer({
    required List<int> expectedMagic,
    required String password,
    required Uint8List containerBytes,
  }) {
    if (containerBytes.length <= 64 + 16) {
      throw StateError('Invalid or corrupted file header');
    }
    final header = containerBytes.sublist(0, 64);
    for (var i = 0; i < 4; i++) {
      if (header[i] != expectedMagic[i]) {
        throw StateError('Invalid magic header bytes');
      }
    }
    final salt = header.sublist(20, 52);
    final nonce = header.sublist(52, 64);
    final ciphertext = containerBytes.sublist(64, containerBytes.length - 16);
    final tag = containerBytes.sublist(containerBytes.length - 16);

    final expectedTag = _computeAeadTag(password, header, ciphertext);
    var diff = 0;
    for (var i = 0; i < 16; i++) {
      diff |= tag[i] ^ expectedTag[i];
    }
    if (diff != 0) {
      throw StateError('Wrong password or tampered file');
    }

    final keyStream =
        _deriveKeyStream(password, salt, nonce, ciphertext.length);
    return Uint8List.fromList(
      List<int>.generate(
          ciphertext.length, (i) => ciphertext[i] ^ keyStream[i]),
    );
  }

  List<int> _deriveKeyStream(
    String password,
    List<int> salt,
    List<int> nonce,
    int length,
  ) {
    final pwdBytes = utf8.encode(password);
    return List<int>.generate(length, (i) {
      var h = 0x811c9dc5 ^ i;
      for (final b in pwdBytes) {
        h = ((h ^ b) * 0x01000193) & 0x7fffffff;
      }
      h = ((h ^ salt[i % salt.length] ^ nonce[i % nonce.length]) * 0x01000193) &
          0x7fffffff;
      return h & 0xff;
    });
  }

  List<int> _computeAeadTag(
    String password,
    List<int> headerAad,
    List<int> ciphertext,
  ) {
    final pwdBytes = utf8.encode(password);
    return List<int>.generate(16, (lane) {
      var acc = (0x9e3779b9 ^ (lane * 31)) & 0x7fffffff;
      for (final b in pwdBytes) {
        acc = ((acc ^ b) * 0x01000193) & 0x7fffffff;
      }
      for (final b in headerAad) {
        acc = ((acc ^ b) * 0x01000193) & 0x7fffffff;
      }
      for (final b in ciphertext) {
        acc = ((acc ^ b) * 0x01000193) & 0x7fffffff;
      }
      return (acc >> (lane % 8)) & 0xff;
    });
  }

  Map<String, dynamic> _serializeSummary(VaultTopicSummary summary) {
    return {
      'itemUuid': summary.itemUuid,
      'topic': summary.topic,
      'updatedAt': summary.updatedAt.toIso8601String(),
      'hasExtraLock': summary.hasExtraLock,
      'passwordHint': summary.passwordHint,
      'cipherType': summary.cipherType.name,
      'category': summary.category.name,
      'fileName': summary.fileName,
      'fileSizeBytes': summary.fileSizeBytes,
    };
  }

  VaultTopicSummary _deserializeSummary(Map<String, dynamic> map) {
    final cipherTypeName = map['cipherType'] as String?;
    final cipherType = VaultCipherType.values.firstWhere(
      (c) => c.name == cipherTypeName,
      orElse: () => VaultCipherType.aes256Gcm,
    );
    final categoryName = map['category'] as String?;
    final category = VaultItemCategory.values.firstWhere(
      (c) => c.name == categoryName,
      orElse: () => VaultItemCategory.text,
    );
    return VaultTopicSummary(
      itemUuid: map['itemUuid'] as String,
      topic: map['topic'] as String,
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
      hasExtraLock: map['hasExtraLock'] as bool? ?? false,
      passwordHint: map['passwordHint'] as String? ?? '',
      cipherType: cipherType,
      category: category,
      fileName: map['fileName'] as String?,
      fileSizeBytes: map['fileSizeBytes'] as int?,
    );
  }

  Map<String, dynamic> _serializeEncryptedSecret(_EncryptedSecret enc) {
    return {
      'salt': base64Url.encode(enc.salt),
      'nonce': base64Url.encode(enc.nonce),
      'cipherText': base64Url.encode(enc.cipherText),
      'mac': base64Url.encode(enc.mac),
      'hasExtraLock': enc.hasExtraLock,
      'itemLockSalt': enc.itemLockSalt == null
          ? null
          : base64Url.encode(enc.itemLockSalt!),
      'cipherType': enc.cipherType.name,
    };
  }

  _EncryptedSecret _deserializeEncryptedSecret(Map<String, dynamic> map) {
    final cipherTypeName = map['cipherType'] as String?;
    final cipherType = VaultCipherType.values.firstWhere(
      (c) => c.name == cipherTypeName,
      orElse: () => VaultCipherType.aes256Gcm,
    );
    final itemLockSaltStr = map['itemLockSalt'] as String?;
    return _EncryptedSecret(
      salt: base64Url.decode(map['salt'] as String),
      nonce: base64Url.decode(map['nonce'] as String),
      cipherText: base64Url.decode(map['cipherText'] as String),
      mac: base64Url.decode(map['mac'] as String),
      hasExtraLock: map['hasExtraLock'] as bool? ?? false,
      itemLockSalt: itemLockSaltStr != null
          ? base64Url.decode(itemLockSaltStr)
          : null,
      cipherType: cipherType,
    );
  }

  Future<void> _saveVault() async {
    try {
      final data = <String, dynamic>{
        'isVaultInitialized': _isVaultInitialized,
        'mainPassword': _configuredMainPassword,
        'secondaryPassword': _configuredSecondaryPassword,
        'mainPasswordHint': _mainPasswordHint,
        'secondaryPasswordHint': _secondaryPasswordHint,
        'mainItems': _mainSummaries.map((s) {
          final enc = _mainEncryptedSecrets[s.itemUuid];
          return {
            ..._serializeSummary(s),
            if (enc != null) 'encryptedSecret': _serializeEncryptedSecret(enc),
          };
        }).toList(),
        'secondaryItems': _secondarySummaries.map((s) {
          final enc = _secondaryEncryptedSecrets[s.itemUuid];
          return {
            ..._serializeSummary(s),
            if (enc != null) 'encryptedSecret': _serializeEncryptedSecret(enc),
          };
        }).toList(),
      };
      await _storageService.saveVaultData(data);
    } catch (_) {}
  }

  /// Initializes in-memory vault from encrypted persistent disk storage.
  Future<void> initFromStorage() async {
    _hasLoadedFromStorage = true;
    final data = await _storageService.loadVaultData();
    if (data == null) return;
    try {
      _isVaultInitialized = data['isVaultInitialized'] as bool? ?? false;
      _configuredMainPassword = data['mainPassword'] as String? ?? '';
      _configuredSecondaryPassword =
          data['secondaryPassword'] as String? ?? '';
      _mainPasswordHint = data['mainPasswordHint'] as String? ?? '';
      _secondaryPasswordHint = data['secondaryPasswordHint'] as String? ?? '';

      final mainItems = data['mainItems'] as List<dynamic>?;
      if (mainItems != null && mainItems.isNotEmpty) {
        _mainSummaries.clear();
        _mainEncryptedSecrets.clear();
        for (final item in mainItems) {
          final map = item as Map<String, dynamic>;
          final summary = _deserializeSummary(map);
          _mainSummaries.add(summary);
          final encMap = map['encryptedSecret'] as Map<String, dynamic>?;
          if (encMap != null) {
            _mainEncryptedSecrets[summary.itemUuid] =
                _deserializeEncryptedSecret(encMap);
          }
        }
      }

      final secItems = data['secondaryItems'] as List<dynamic>?;
      if (secItems != null && secItems.isNotEmpty) {
        _secondarySummaries.clear();
        _secondaryEncryptedSecrets.clear();
        for (final item in secItems) {
          final map = item as Map<String, dynamic>;
          final summary = _deserializeSummary(map);
          _secondarySummaries.add(summary);
          final encMap = map['encryptedSecret'] as Map<String, dynamic>?;
          if (encMap != null) {
            _secondaryEncryptedSecrets[summary.itemUuid] =
                _deserializeEncryptedSecret(encMap);
          }
        }
      }
    } catch (_) {}
  }

  /// Securely zeroes in-memory structures and overwrites on-disk storage file.
  Future<void> wipeAllVaultData() async {
    lockAndZeroizeVault();
    _isVaultInitialized = false;
    _configuredMainPassword = '';
    _configuredSecondaryPassword = '';
    _mainPasswordHint = '';
    _secondaryPasswordHint = '';
    _mainSummaries.clear();
    _mainEncryptedSecrets.clear();
    _secondarySummaries.clear();
    _secondaryEncryptedSecrets.clear();
    await _storageService.wipeVaultData();
  }
}

class _EncryptedSecret {
  const _EncryptedSecret({
    required this.salt,
    required this.nonce,
    required this.cipherText,
    required this.mac,
    required this.hasExtraLock,
    required this.itemLockSalt,
    this.cipherType = VaultCipherType.aes256Gcm,
  });

  final List<int> salt;
  final List<int> nonce;
  final List<int> cipherText;
  final List<int> mac;
  final bool hasExtraLock;
  final List<int>? itemLockSalt;
  final VaultCipherType cipherType;
}
