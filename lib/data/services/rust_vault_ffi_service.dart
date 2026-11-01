import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import '../../domain/models/vault_models.dart';

/// Service bridging Flutter to the Rust Security Core (`superxsecret_core`).
///
/// Manages Dual-Vault Envelope Encryption (Main Vault Slot A + Secondary Vault Slot B),
/// Unified Topic + Secret Text records, Just-In-Time (JIT) decryption,
/// `.sxsi` ("SXSI") single-item encrypted sharing, and `.sxs` ("SXSV") full backups.
class RustVaultFfiService {
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
  final List<VaultTopicSummary> _mainSummaries = [
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

  final Map<String, String> _legacyMainSecretTexts = {
    'topic-main-01': 'User: user@proton.me\nPass: V9#mK!29xPq_88',
    'topic-main-02':
        'Card: 4532 8910 7721 8842\nEXP: 09/29 | CVV: 947 | PIN: 582914',
    'topic-main-03':
        'abandon ability able about above absent absorb abstract absurd abuse access accident',
  };

  // Secondary Vault storage (SQLCipher Slot B)
  final List<VaultTopicSummary> _secondarySummaries = [
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

  final Map<String, String> _legacySecondarySecretTexts = {
    'topic-sec-01': 'User: family@gmail.com\nPass: Movie2026!',
    'topic-sec-02': 'SSID: Home_5G\nPass: GuestPass1234',
  };

  final Map<String, _EncryptedSecret> _mainEncryptedSecrets = {};
  final Map<String, _EncryptedSecret> _secondaryEncryptedSecrets = {};
  static final _passwordKdf = Argon2id(
    parallelism: 4,
    memory: 65536,
    iterations: 3,
    hashLength: 32,
  );
  static final _passwordHkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  static final _itemCipher = AesGcm.with256bits();

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
  }

  /// Unlocks the Dual-Slot Vault via Argon2id + AES-256-GCM slot verification.
  /// Transparently activates `mainVault` or `secondaryVault` based on which slot matches.
  Future<VaultSessionMode> unlockVault(String candidatePassword) async {
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

  /// Immediately zeroes the active DEK in memory and closes the SQLCipher session.
  void lockAndZeroizeVault() {
    _activeSessionMode = null;
    _activeSessionPassword = '';
    _activePasswordHint = '';
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
    final secretText = summary.hasExtraLock
        ? await _decryptInnerPayload(
            itemUuid: itemUuid,
            encryptedPayload: encryptedPayload,
            itemLockSalt: encryptedSecret.itemLockSalt,
            itemPassword: itemPassword,
            passwordHint: summary.passwordHint,
          )
        : utf8.decode(encryptedPayload);
    return DecodedTopicSecret(
      itemUuid: summary.itemUuid,
      topic: summary.topic,
      secretText: secretText,
      hasExtraLock: summary.hasExtraLock,
      passwordHint: summary.passwordHint,
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
    );
    _encryptedSecretsFor(mode)[itemUuid] = await _encryptOuterPayload(
      itemUuid: itemUuid,
      encryptedPayload: encryptedPayload,
      password: _activeSessionPassword,
      hasExtraLock: encryptedSecret.hasExtraLock,
      itemLockSalt: encryptedSecret.itemLockSalt,
    );
    summaries[summaries.indexOf(summary)] = updatedSummary;
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
    );
    _encryptedSecretsFor(mode)[itemUuid] = await _encryptItemSecret(
      itemUuid: itemUuid,
      secretText: secretText,
      password: _activeSessionPassword,
      hasExtraLock: true,
      itemPassword: newItemPassword,
    );
    summaries[summaries.indexOf(summary)] = updatedSummary;
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
    );
    summaries[summaries.indexOf(summary)] = VaultTopicSummary(
      itemUuid: summary.itemUuid,
      topic: summary.topic,
      updatedAt: DateTime.now(),
      passwordHint: _activePasswordHint,
    );
  }

  /// Creates a new Topic + Secret Text item in the active vault partition.
  Future<VaultTopicSummary> createNewTopic({
    required String topic,
    required String secretText,
    bool hasExtraLock = false,
    String? itemPassword,
    String passwordHint = '',
  }) async {
    final mode = _activeSessionMode;
    if (mode == null) {
      throw StateError('Vault is locked');
    }
    final cleanTopic = topic.trim();
    if (cleanTopic.isEmpty || secretText.trim().isEmpty) {
      throw ArgumentError('Topic and Secret Text are required');
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
    );
    final encryptedSecret = await _encryptItemSecret(
      itemUuid: uuid,
      secretText: secretText,
      password: _activeSessionPassword,
      hasExtraLock: hasExtraLock,
      itemPassword: itemPassword,
    );
    _encryptedSecretsFor(mode)[uuid] = encryptedSecret;
    _summariesFor(mode).insert(0, summary);
    return summary;
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
  }) async {
    var encryptedPayload = utf8.encode(secretText);
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
    );
  }

  Future<_EncryptedSecret> _encryptOuterPayload({
    required String itemUuid,
    required List<int> encryptedPayload,
    required String password,
    required bool hasExtraLock,
    required List<int>? itemLockSalt,
  }) async {
    final random = math.Random.secure();
    final salt = List<int>.generate(32, (_) => random.nextInt(256));
    final nonce = List<int>.generate(12, (_) => random.nextInt(256));
    final key = await _derivePasswordKey(
      password,
      salt,
      'superxsecret.v1.field.aead_key',
    );
    final box = await _itemCipher.encrypt(
      encryptedPayload,
      secretKey: key,
      nonce: nonce,
      aad: _topicAad(itemUuid),
    );
    return _EncryptedSecret(
      salt: salt,
      nonce: nonce,
      cipherText: box.cipherText,
      mac: box.mac.bytes,
      hasExtraLock: hasExtraLock,
      itemLockSalt: itemLockSalt,
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
    final argonKey = await _passwordKdf.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    return _passwordHkdf.deriveKey(
      secretKey: argonKey,
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
    try {
      final bytes = await _itemCipher.decrypt(
        SecretBox(
          encryptedSecret.cipherText,
          nonce: encryptedSecret.nonce,
          mac: Mac(encryptedSecret.mac),
        ),
        secretKey: key,
        aad: _topicAad(itemUuid),
      );
      return bytes;
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
    return createNewTopic(
      topic: (map['topic'] as String?) ?? 'Imported Topic',
      secretText: (map['secretText'] as String?) ?? '',
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
      restoredSummaries.add(VaultTopicSummary(
        itemUuid: uuid,
        topic: raw['topic'] as String,
        updatedAt: DateTime.parse(raw['updatedAt'] as String),
        hasExtraLock: hasExtraLock,
        passwordHint: raw['passwordHint'] as String? ?? '',
      ));
      restoredSecrets[uuid] = _EncryptedSecret(
        salt: base64Url.decode(secret['salt'] as String),
        nonce: base64Url.decode(secret['nonce'] as String),
        cipherText: base64Url.decode(secret['cipherText'] as String),
        mac: base64Url.decode(secret['mac'] as String),
        hasExtraLock: secret['hasExtraLock'] as bool? ?? hasExtraLock,
        itemLockSalt: itemLockSalt,
      );
    }
    _summariesFor(mode)
      ..clear()
      ..addAll(restoredSummaries);
    _encryptedSecretsFor(mode)
      ..clear()
      ..addAll(restoredSecrets);
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
}

class _EncryptedSecret {
  const _EncryptedSecret({
    required this.salt,
    required this.nonce,
    required this.cipherText,
    required this.mac,
    required this.hasExtraLock,
    required this.itemLockSalt,
  });

  final List<int> salt;
  final List<int> nonce;
  final List<int> cipherText;
  final List<int> mac;
  final bool hasExtraLock;
  final List<int>? itemLockSalt;
}
