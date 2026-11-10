import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controller managing Pro Licensing, Freemium Tier Limits, and
/// 100% Offline Cryptographic Ed25519 License Verification.
class LicenseController extends ChangeNotifier {
  static const String _prefLicenseKey = 'superxsecret.license.key';

  /// Official SuperXSecret Authority Ed25519 Public Key.
  /// Used to mathematically verify offline license keys without any server requests.
  static const String rootPublicKeyHex =
      '12f21eaea1309b4b9b37fba2dd9af60ccd8a3ca1d1744623c796a9c668a8b0eb';

  /// Maximum items allowed in the Free Tier.
  static const int maxFreeItems = 3;

  /// Whether a specific category is permitted under the current license.
  /// Free Tier only permits Text secrets. Pro unlocks all media/file categories.
  bool isCategoryAllowed(String category) {
    if (_isPro) return true;
    return category.toLowerCase() == 'text';
  }

  bool _isPro = false;
  String? _licenseKey;
  String? _licenseOwner;
  String? _licensePlan;
  DateTime? _issuedAt;

  bool get isPro => _isPro;
  String? get licenseKey => _licenseKey;
  String? get licenseOwner => _licenseOwner;
  String? get licensePlan => _licensePlan;
  DateTime? get issuedAt => _issuedAt;

  /// Loads saved license from SharedPreferences and verifies its signature.
  Future<void> loadLicense() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedKey = prefs.getString(_prefLicenseKey);
      if (savedKey != null && savedKey.isNotEmpty) {
        final verified = await _verifyLicenseKey(savedKey);
        if (verified) {
          _licenseKey = savedKey;
          _isPro = true;
          notifyListeners();
          return;
        }
      }
    } catch (e) {
      debugPrint('[LicenseController] Error loading license: $e');
    }

    _isPro = false;
    _licenseKey = null;
    _licenseOwner = null;
    _licensePlan = null;
    _issuedAt = null;
    notifyListeners();
  }

  /// Verifies and activates a candidate license key.
  Future<bool> activateLicense(String candidateKey) async {
    final verified = await _verifyLicenseKey(candidateKey);
    if (!verified) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefLicenseKey, candidateKey.trim());
    } catch (e) {
      debugPrint('[LicenseController] Error saving license: $e');
    }

    _licenseKey = candidateKey.trim();
    _isPro = true;
    notifyListeners();
    return true;
  }

  /// Deactivates and removes the current license key.
  Future<void> deactivateLicense() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefLicenseKey);
    } catch (e) {
      debugPrint('[LicenseController] Error removing license: $e');
    }

    _isPro = false;
    _licenseKey = null;
    _licenseOwner = null;
    _licensePlan = null;
    _issuedAt = null;
    notifyListeners();
  }

  /// Internal cryptographic verification using Ed25519.
  Future<bool> _verifyLicenseKey(String key) async {
    final cleanKey = key.trim();
    if (!cleanKey.startsWith('SXS-')) return false;

    final body = cleanKey.substring(4);
    final dotIndex = body.indexOf('.');
    if (dotIndex == -1) return false;

    final payloadB64 = body.substring(0, dotIndex);
    final signatureB64 = body.substring(dotIndex + 1);

    try {
      final payloadBytes = base64Url.decode(_normalizeB64(payloadB64));
      final signatureBytes = base64Url.decode(_normalizeB64(signatureB64));

      final payloadJson = utf8.decode(payloadBytes);
      final payloadMap = jsonDecode(payloadJson) as Map<String, dynamic>;

      if (payloadMap['app'] != 'superxsecret') return false;

      final pubBytes = _hexToBytes(rootPublicKeyHex);
      final algorithm = Ed25519();
      final publicKey = SimplePublicKey(pubBytes, type: KeyPairType.ed25519);

      final isSignatureValid = await algorithm.verify(
        payloadBytes,
        signature: Signature(signatureBytes, publicKey: publicKey),
      );

      if (!isSignatureValid) return false;

      _licenseOwner = payloadMap['owner']?.toString();
      _licensePlan = payloadMap['plan']?.toString() ?? 'lifetime';
      if (payloadMap['issued_at'] != null) {
        _issuedAt = DateTime.tryParse(payloadMap['issued_at'].toString());
      }

      return true;
    } catch (e) {
      debugPrint('[LicenseController] Verification exception: $e');
      return false;
    }
  }

  String _normalizeB64(String input) {
    var str = input.replaceAll('-', '+').replaceAll('_', '/');
    while (str.length % 4 != 0) {
      str += '=';
    }
    return str;
  }

  List<int> _hexToBytes(String hex) {
    final result = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      result.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return result;
  }
}

/// InheritedWidget providing access to [LicenseController] down the tree.
class LicenseScope extends InheritedWidget {
  const LicenseScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final LicenseController controller;

  static LicenseController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LicenseScope>();
    assert(scope != null, 'No LicenseScope found in context');
    return scope!.controller;
  }

  @override
  bool updateShouldNotify(LicenseScope oldWidget) =>
      controller != oldWidget.controller;
}
