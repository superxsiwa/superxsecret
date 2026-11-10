import 'package:flutter/material.dart';
import 'data/repositories/vault_repository.dart';
import 'data/services/os_hardening_service.dart';
import 'data/services/rust_vault_ffi_service.dart';
import 'ui/core/controllers/auto_lock_controller.dart';
import 'ui/core/controllers/license_controller.dart';
import 'ui/core/localization/app_localizations.dart';
import 'ui/core/theme/app_theme.dart';
import 'ui/core/widgets/privacy_curtain_wrapper.dart';
import 'ui/features/auth/view_models/auth_view_model.dart';
import 'ui/features/auth/views/lock_screen_view.dart';
import 'ui/features/auth/views/quick_pin_lock_view.dart';
import 'ui/features/vault/view_models/vault_view_model.dart';
import 'ui/features/vault/views/vault_dashboard_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final rustFfiService = RustVaultFfiService();
  await rustFfiService.initFromStorage();

  final osHardeningService = OsHardeningService();
  final vaultRepository = VaultRepository(
    rustFfiService: rustFfiService,
    osHardeningService: osHardeningService,
  );

  runApp(SuperXSecretApp(vaultRepository: vaultRepository));
}

class SuperXSecretApp extends StatefulWidget {
  const SuperXSecretApp({
    super.key,
    required this.vaultRepository,
  });

  final VaultRepository vaultRepository;

  @override
  State<SuperXSecretApp> createState() => _SuperXSecretAppState();
}

class _SuperXSecretAppState extends State<SuperXSecretApp> {
  late final AuthViewModel _authViewModel;
  late final VaultViewModel _vaultViewModel;
  final AppLanguageController _languageController = AppLanguageController();
  final AppThemeController _themeController = AppThemeController();
  final AutoLockController _autoLockController = AutoLockController();
  final LicenseController _licenseController = LicenseController();
  bool _isVaultUnlocked = false;

  @override
  void initState() {
    super.initState();
    _authViewModel = AuthViewModel(vaultRepository: widget.vaultRepository);
    _vaultViewModel = VaultViewModel(vaultRepository: widget.vaultRepository);
    _languageController.loadSavedLanguage();
    _themeController.loadSavedTheme();
    _autoLockController.loadSettings();
    _licenseController.loadLicense();

    widget.vaultRepository.bindOsSecurityCallbacks(
      onScreenOffAutoLock: () {
        if (_isVaultUnlocked) {
          if (_autoLockController.screenOffTimeoutMinutes == 0) {
            _handleImmediateAutoLock();
          } else if (_autoLockController.isPinConfigured &&
              _autoLockController.screenOffTimeoutMinutes > 0) {
            _autoLockController.onAppPaused(
              onImmediateHardLock: _handleImmediateAutoLock,
            );
          } else {
            _handleImmediateAutoLock();
          }
        }
      },
      onScreenRecordingDetected: (isCaptured) {
        if (isCaptured) {
          _vaultViewModel.hideAndZeroizeRevealedSecret();
        }
      },
      onClipboardCleared: () {},
    );
  }

  void _handleImmediateAutoLock() {
    if (!mounted) return;
    _autoLockController.resetSession();
    _vaultViewModel.hideAndZeroizeRevealedSecret();
    _authViewModel.lockVault();
    setState(() => _isVaultUnlocked = false);
  }

  @override
  void dispose() {
    _licenseController.dispose();
    _autoLockController.dispose();
    _languageController.dispose();
    _themeController.dispose();
    _authViewModel.dispose();
    _vaultViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        _languageController,
        _themeController,
        _autoLockController,
        _licenseController,
      ]),
      builder: (context, _) {
        return AppLanguageScope(
          controller: _languageController,
          child: AppThemeScope(
            controller: _themeController,
            child: AutoLockScope(
              controller: _autoLockController,
              child: LicenseScope(
                controller: _licenseController,
                child: MaterialApp(
                  title: 'SuperXSecret Offline Vault',
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.lightVaultTheme,
                  darkTheme: AppTheme.darkVaultTheme,
                  themeMode: _themeController.themeMode,
                  builder: (context, child) {
                    return Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: (_) {
                        if (_isVaultUnlocked) {
                          _autoLockController.recordActivity(
                            onHardLogout: _handleImmediateAutoLock,
                          );
                        }
                      },
                      onPointerMove: (_) {
                        if (_isVaultUnlocked) {
                          _autoLockController.recordActivity(
                            onHardLogout: _handleImmediateAutoLock,
                          );
                        }
                      },
                      child: PrivacyCurtainWrapper(
                        onBackgroundAutoLock: () {
                          if (_isVaultUnlocked) {
                            _autoLockController.onAppPaused(
                              onImmediateHardLock: _handleImmediateAutoLock,
                            );
                          } else {
                            _handleImmediateAutoLock();
                          }
                        },
                        onAppResumed: () {
                          if (_isVaultUnlocked) {
                            _autoLockController.onAppResumed(
                              onHardLogout: _handleImmediateAutoLock,
                            );
                          }
                        },
                        child: child ?? const SizedBox.shrink(),
                      ),
                    );
                  },
                  home: !_isVaultUnlocked
                      ? LockScreenView(
                          viewModel: _authViewModel,
                          onVaultUnlocked: () {
                            _autoLockController.resetSession();
                            _autoLockController.recordActivity(
                              onHardLogout: _handleImmediateAutoLock,
                            );
                            setState(() => _isVaultUnlocked = true);
                          },
                        )
                      : (_autoLockController.isSoftLocked &&
                              _autoLockController.isPinConfigured
                          ? QuickPinLockView(
                              autoLockController: _autoLockController,
                              onHardLogoutRequested: _handleImmediateAutoLock,
                            )
                          : VaultDashboardView(
                              viewModel: _vaultViewModel,
                              autoLockController: _autoLockController,
                              licenseController: _licenseController,
                              onLockRequested: _handleImmediateAutoLock,
                            )),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

