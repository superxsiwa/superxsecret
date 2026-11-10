import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controller coordinating Inactivity Auto-Lock, Background Screen-Off Timeout,
/// and Quick PIN Security Lifecycle.
class AutoLockController extends ChangeNotifier {
  static const String _prefTimeoutMinutes = 'superxsecret.autolock.timeout_minutes';
  static const String _prefInactivityTimeout = 'superxsecret.autolock.inactivity_timeout_minutes';
  static const String _prefScreenOffTimeout = 'superxsecret.autolock.screen_off_timeout_minutes';
  static const String _prefPinSalt = 'superxsecret.autolock.pin_salt';
  static const String _prefPinHash = 'superxsecret.autolock.pin_hash';

  int _inactivityTimeoutMinutes = 1; // Default 1 minute
  int _screenOffTimeoutMinutes = 1;  // Default 1 minute (0 = immediate)
  bool _isPinConfigured = false;
  String? _savedPinSalt;
  String? _savedPinHash;

  bool _isSoftLocked = false;
  int _pinAttemptsRemaining = 3;
  DateTime? _lastActivityTime;
  DateTime? _backgroundedTime;
  DateTime? _softLockedTime;
  Timer? _inactivityTimer;
  Timer? _hardLogoutTimer;

  int get inactivityTimeoutMinutes => _inactivityTimeoutMinutes;
  int get screenOffTimeoutMinutes => _screenOffTimeoutMinutes;
  int get timeoutMinutes => _inactivityTimeoutMinutes;
  bool get isPinConfigured => _isPinConfigured;
  bool get isSoftLocked => _isSoftLocked;
  int get pinAttemptsRemaining => _pinAttemptsRemaining;
  DateTime? get softLockedTime => _softLockedTime;
  DateTime? get lastActivityTime => _lastActivityTime;

  /// Loads persisted settings from SharedPreferences.
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _inactivityTimeoutMinutes = prefs.getInt(_prefInactivityTimeout) ??
          prefs.getInt(_prefTimeoutMinutes) ?? 1;
      _screenOffTimeoutMinutes = prefs.getInt(_prefScreenOffTimeout) ?? 1;
      _savedPinSalt = prefs.getString(_prefPinSalt);
      _savedPinHash = prefs.getString(_prefPinHash);
      _isPinConfigured = _savedPinSalt != null && _savedPinHash != null;
      notifyListeners();
    } catch (e) {
      debugPrint('[AutoLockController] Error loading settings: $e');
    }
  }

  /// Sets in-app inactivity timeout in minutes (0 = disabled, 1, 2, 3, 5).
  Future<void> setInactivityTimeoutMinutes(
    int minutes, {
    VoidCallback? onHardLogout,
  }) async {
    _inactivityTimeoutMinutes = minutes;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefInactivityTimeout, minutes);
    } catch (e) {
      debugPrint('[AutoLockController] Error saving inactivity timeout: $e');
    }
    if (onHardLogout != null) {
      recordActivity(onHardLogout: onHardLogout);
    }
    notifyListeners();
  }

  /// Sets screen off / background timeout in minutes (0 = immediate, 1, 2, 3, 5).
  Future<void> setScreenOffTimeoutMinutes(int minutes) async {
    _screenOffTimeoutMinutes = minutes;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefScreenOffTimeout, minutes);
    } catch (e) {
      debugPrint('[AutoLockController] Error saving screen off timeout: $e');
    }
    notifyListeners();
  }

  /// Sets the timeout in minutes (backward-compatible alias for in-app inactivity).
  Future<void> setTimeoutMinutes(
    int minutes, {
    VoidCallback? onHardLogout,
  }) =>
      setInactivityTimeoutMinutes(minutes, onHardLogout: onHardLogout);

  /// Configures a new Quick PIN using CSPRNG Salt + SHA-256.
  Future<void> setQuickPin(String pin) async {
    final rng = math.Random.secure();
    final saltBytes = List<int>.generate(16, (_) => rng.nextInt(256));
    final saltHex = _bytesToHex(saltBytes);
    final hashHex = await _calculateHash(pin, saltBytes);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefPinSalt, saltHex);
      await prefs.setString(_prefPinHash, hashHex);
    } catch (e) {
      debugPrint('[AutoLockController] Error saving PIN: $e');
    }

    _savedPinSalt = saltHex;
    _savedPinHash = hashHex;
    _isPinConfigured = true;
    notifyListeners();
  }

  /// Removes the Quick PIN, disabling soft PIN lock.
  Future<void> removeQuickPin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefPinSalt);
      await prefs.remove(_prefPinHash);
    } catch (e) {
      debugPrint('[AutoLockController] Error removing PIN: $e');
    }

    _savedPinSalt = null;
    _savedPinHash = null;
    _isPinConfigured = false;
    _isSoftLocked = false;
    notifyListeners();
  }

  /// Verifies entered PIN. If wrong 3 times, triggers hard logout immediately.
  Future<bool> verifyAndUnlockWithPin(
    String candidatePin, {
    required VoidCallback onHardLogout,
  }) async {
    if (!_isPinConfigured || _savedPinSalt == null || _savedPinHash == null) {
      return false;
    }

    final saltBytes = _hexToBytes(_savedPinSalt!);
    final candidateHash = await _calculateHash(candidatePin, saltBytes);

    if (candidateHash == _savedPinHash) {
      _isSoftLocked = false;
      _pinAttemptsRemaining = 3;
      _softLockedTime = null;
      _hardLogoutTimer?.cancel();
      recordActivity(onHardLogout: onHardLogout);
      notifyListeners();
      return true;
    } else {
      _pinAttemptsRemaining--;
      if (_pinAttemptsRemaining <= 0) {
        _isSoftLocked = false;
        _pinAttemptsRemaining = 3;
        _softLockedTime = null;
        _hardLogoutTimer?.cancel();
        notifyListeners();
        onHardLogout();
        return false;
      }
      notifyListeners();
      return false;
    }
  }

  /// Resets the inactivity timer on user interaction.
  void recordActivity({required VoidCallback onHardLogout}) {
    if (_isSoftLocked) return;
    _lastActivityTime = DateTime.now();
    _inactivityTimer?.cancel();

    if (_inactivityTimeoutMinutes > 0) {
      _inactivityTimer = Timer(Duration(minutes: _inactivityTimeoutMinutes), () {
        if (_isPinConfigured) {
          _isSoftLocked = true;
          _softLockedTime = DateTime.now();
          _pinAttemptsRemaining = 3;
          notifyListeners();

          // Hard logout if remaining soft-locked for screenOffTimeoutMinutes
          final maxGrace = _screenOffTimeoutMinutes > 0
              ? _screenOffTimeoutMinutes
              : _inactivityTimeoutMinutes;
          _hardLogoutTimer?.cancel();
          _hardLogoutTimer = Timer(Duration(minutes: maxGrace), () {
            if (_isSoftLocked) {
              _isSoftLocked = false;
              _softLockedTime = null;
              notifyListeners();
              onHardLogout();
            }
          });
        } else {
          onHardLogout();
        }
      });
    }
  }

  /// Called when app goes into background or screen turns off.
  void onAppPaused({required VoidCallback onImmediateHardLock}) {
    _backgroundedTime = DateTime.now();
    _inactivityTimer?.cancel();

    if (_screenOffTimeoutMinutes == 0) {
      onImmediateHardLock();
    } else if (_isPinConfigured) {
      _isSoftLocked = true;
      _softLockedTime = DateTime.now();
      _pinAttemptsRemaining = 3;
      notifyListeners();
    } else {
      onImmediateHardLock();
    }
  }

  /// Called when app resumes from background or screen turns back on.
  void onAppResumed({required VoidCallback onHardLogout}) {
    if (_backgroundedTime == null) return;
    final elapsed = DateTime.now().difference(_backgroundedTime!);
    _backgroundedTime = null;

    if (_screenOffTimeoutMinutes == 0) {
      _isSoftLocked = false;
      _softLockedTime = null;
      _hardLogoutTimer?.cancel();
      notifyListeners();
      onHardLogout();
      return;
    }

    if (_screenOffTimeoutMinutes > 0 &&
        elapsed.inSeconds >= _screenOffTimeoutMinutes * 60) {
      // Exceeded screen off timeout -> HARD LOGOUT!
      _isSoftLocked = false;
      _softLockedTime = null;
      _hardLogoutTimer?.cancel();
      notifyListeners();
      onHardLogout();
    } else if (_isPinConfigured) {
      // Within grace period -> SOFT LOCK with Quick PIN
      _isSoftLocked = true;
      _softLockedTime ??= DateTime.now();
      notifyListeners();
    }
  }

  /// Checks if the soft lock has expired while active on screen.
  void checkSoftLockExpiry({required VoidCallback onHardLogout}) {
    if (_isSoftLocked && _softLockedTime != null) {
      final maxWaitMinutes = _screenOffTimeoutMinutes > 0
          ? _screenOffTimeoutMinutes
          : (_inactivityTimeoutMinutes > 0 ? _inactivityTimeoutMinutes : 1);
      final elapsed = DateTime.now().difference(_softLockedTime!);
      if (elapsed.inSeconds >= maxWaitMinutes * 60) {
        _isSoftLocked = false;
        _softLockedTime = null;
        _hardLogoutTimer?.cancel();
        notifyListeners();
        onHardLogout();
      }
    }
  }

  /// Cleans up session state upon vault lock or logout.
  void resetSession() {
    _isSoftLocked = false;
    _pinAttemptsRemaining = 3;
    _lastActivityTime = null;
    _backgroundedTime = null;
    _softLockedTime = null;
    _inactivityTimer?.cancel();
    _hardLogoutTimer?.cancel();
  }

  /// Cancels any scheduled background timers.
  void cancelTimers() {
    _inactivityTimer?.cancel();
    _hardLogoutTimer?.cancel();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    _hardLogoutTimer?.cancel();
    super.dispose();
  }

  Future<String> _calculateHash(String pin, List<int> saltBytes) async {
    final pinBytes = utf8.encode(pin);
    final combined = [...saltBytes, ...pinBytes];
    final digest = await Sha256().hash(combined);
    return _bytesToHex(digest.bytes);
  }

  String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  List<int> _hexToBytes(String hex) {
    final result = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      result.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return result;
  }
}

/// InheritedWidget providing access to [AutoLockController] down the tree.
class AutoLockScope extends InheritedWidget {
  const AutoLockScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final AutoLockController controller;

  static AutoLockController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AutoLockScope>();
    assert(scope != null, 'No AutoLockScope found in context');
    return scope!.controller;
  }

  @override
  bool updateShouldNotify(AutoLockScope oldWidget) =>
      controller != oldWidget.controller;
}
