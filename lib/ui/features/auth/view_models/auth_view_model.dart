import 'package:flutter/foundation.dart';
import '../../../../data/repositories/vault_repository.dart';
import '../../../../domain/models/vault_models.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({required VaultRepository vaultRepository})
      : _vaultRepository = vaultRepository;

  final VaultRepository _vaultRepository;

  DeviceSecurityPosture _securityPosture = const DeviceSecurityPosture(
    zeroNetworkPermissionVerified: true,
    isScreenGuardActive: true,
    isCompromised: false,
    hasRootOrJailbreak: false,
    isDebuggerOrFridaDetected: false,
    sqlCipherActive: true,
  );
  DeviceSecurityPosture get securityPosture => _securityPosture;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  double _currentEntropyBits = 0;
  double get currentEntropyBits => _currentEntropyBits;

  bool get isVaultInitialized => _vaultRepository.isVaultInitialized;
  VaultSessionMode? get activeSessionMode => _vaultRepository.activeSessionMode;

  Future<void> initializeSecurityCheck() async {
    _securityPosture = await _vaultRepository.checkDeviceSecurityPosture();
    notifyListeners();
  }

  void updatePasswordInputForEntropy(String candidate) {
    _currentEntropyBits =
        _vaultRepository.estimatePasswordEntropyBits(candidate);
    if (_errorMessage != null) {
      _errorMessage = null;
    }
    notifyListeners();
  }

  Future<bool> setupDualSlotVault({
    required String mainPassword,
    required String secondaryPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _vaultRepository.setupDualSlotVault(
        mainPassword: mainPassword,
        secondaryPassword: secondaryPassword,
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Invalid argument(s): ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  Future<bool> unlockWithPassword(String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _vaultRepository.unlockVault(password);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Bad state: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void lockVault() {
    _vaultRepository.lockVaultImmediately();
    _currentEntropyBits = 0;
    _errorMessage = null;
    notifyListeners();
  }
}

