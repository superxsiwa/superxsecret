import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cross-platform persistence service for SuperXSecret.
///
/// Features:
/// - Persists encrypted vault ciphertext and metadata.
/// - Atomic write on Android/Desktop to eliminate file corruption risk.
/// - Secure zeroization of on-disk bytes before deletion.
/// - SharedPreferences integration for user preferences (Theme & Language).
/// - Web fallback using SharedPreferences.
class VaultStorageService {
  VaultStorageService({
    this.customStorageDirectory,
  });

  final Directory? customStorageDirectory;
  Map<String, dynamic>? _inMemoryFallback;
  final Map<String, String> _inMemoryPrefs = {};

  static const String _vaultStorageFileName = 'superxsecret_vault_v1.enc.json';
  static const String _webStorageKey = 'superxsecret_vault_container_v1';
  static const String prefLanguageKey = 'superxsecret_pref_language';
  static const String prefThemeKey = 'superxsecret_pref_theme';

  bool get _isTesting =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  Future<File?> _getVaultFile() async {
    if (kIsWeb) return null;
    if (customStorageDirectory != null) {
      final dir = customStorageDirectory!;
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      return File('${dir.path}/$_vaultStorageFileName');
    }
    if (_isTesting) {
      // In headless unit/widget tests without customStorageDirectory, avoid platform channels
      return null;
    }
    try {
      final dir = await getApplicationSupportDirectory();
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      return File('${dir.path}/$_vaultStorageFileName');
    } catch (_) {
      return null;
    }
  }

  /// Saves the complete encrypted vault structure atomically to disk.
  Future<void> saveVaultData(Map<String, dynamic> data) async {
    final jsonStr = jsonEncode(data);

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_webStorageKey, jsonStr);
      } catch (_) {}
      return;
    }

    final file = await _getVaultFile();
    if (file == null) {
      // In-memory fallback for headless test runners
      _inMemoryFallback = Map<String, dynamic>.from(data);
      return;
    }

    // Atomic write pattern: write to tmp file first, then atomic rename
    final tmpFile = File('${file.path}.tmp');
    await tmpFile.writeAsString(jsonStr, flush: true);
    await tmpFile.rename(file.path);
  }

  /// Loads the encrypted vault structure from disk.
  Future<Map<String, dynamic>?> loadVaultData() async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_webStorageKey);
        if (raw == null || raw.isEmpty) return null;
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }

    final file = await _getVaultFile();
    if (file != null && await file.exists()) {
      try {
        final raw = await file.readAsString();
        if (raw.trim().isNotEmpty) {
          return jsonDecode(raw) as Map<String, dynamic>;
        }
      } catch (_) {
        return null;
      }
    }

    // In-memory fallback for test runners
    if (_inMemoryFallback != null) {
      return Map<String, dynamic>.from(_inMemoryFallback!);
    }

    return null;
  }

  /// Securely overwrites the vault storage file with zeroes before deleting it.
  Future<void> wipeVaultData() async {
    _inMemoryFallback = null;
    _inMemoryPrefs.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_webStorageKey);
    } catch (_) {}

    if (!kIsWeb) {
      final file = await _getVaultFile();
      if (file != null && await file.exists()) {
        try {
          final length = await file.length();
          final zeroes = Uint8List(length);
          await file.writeAsBytes(zeroes, flush: true);
          await file.delete();
        } catch (_) {}
      }
    }
  }

  /// Persists a user preference string (such as language or theme).
  Future<void> savePreference(String key, String value) async {
    _inMemoryPrefs[key] = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (_) {}
  }

  /// Retrieves a saved preference string.
  Future<String?> loadPreference(String key) async {
    if (_inMemoryPrefs.containsKey(key)) return _inMemoryPrefs[key];
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } catch (_) {
      return null;
    }
  }
}
