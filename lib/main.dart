import 'package:flutter/material.dart';
import 'data/repositories/vault_repository.dart';
import 'data/services/os_hardening_service.dart';
import 'data/services/rust_vault_ffi_service.dart';
import 'ui/core/localization/app_localizations.dart';
import 'ui/core/theme/app_theme.dart';
import 'ui/core/widgets/privacy_curtain_wrapper.dart';
import 'ui/features/auth/view_models/auth_view_model.dart';
import 'ui/features/auth/views/lock_screen_view.dart';
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
  bool _isVaultUnlocked = false;

  @override
  void initState() {
    super.initState();
    _authViewModel = AuthViewModel(vaultRepository: widget.vaultRepository);
    _vaultViewModel = VaultViewModel(vaultRepository: widget.vaultRepository);
    _languageController.loadSavedLanguage();
    _themeController.loadSavedTheme();

    widget.vaultRepository.bindOsSecurityCallbacks(
      onScreenOffAutoLock: _handleImmediateAutoLock,
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
    _vaultViewModel.hideAndZeroizeRevealedSecret();
    _authViewModel.lockVault();
    setState(() => _isVaultUnlocked = false);
  }

  @override
  void dispose() {
    _languageController.dispose();
    _themeController.dispose();
    _authViewModel.dispose();
    _vaultViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_languageController, _themeController]),
      builder: (context, _) {
        return AppLanguageScope(
          controller: _languageController,
          child: AppThemeScope(
            controller: _themeController,
            child: MaterialApp(
              title: 'SuperXSecret Offline Vault',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightVaultTheme,
              darkTheme: AppTheme.darkVaultTheme,
              themeMode: _themeController.themeMode,
              builder: (context, child) {
                return PrivacyCurtainWrapper(
                  onBackgroundAutoLock: _handleImmediateAutoLock,
                  child: child ?? const SizedBox.shrink(),
                );
              },
              home: _isVaultUnlocked
                  ? VaultDashboardView(
                      viewModel: _vaultViewModel,
                      onLockRequested: _handleImmediateAutoLock,
                    )
                  : LockScreenView(
                      viewModel: _authViewModel,
                      onVaultUnlocked: () =>
                          setState(() => _isVaultUnlocked = true),
                    ),
            ),
          ),
        );
      },
    );
  }
}

