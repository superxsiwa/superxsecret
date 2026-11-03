import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superxsecret/data/repositories/vault_repository.dart';
import 'package:superxsecret/data/services/os_hardening_service.dart';
import 'package:superxsecret/data/services/rust_vault_ffi_service.dart';
import 'package:superxsecret/ui/core/localization/app_localizations.dart';
import 'package:superxsecret/ui/features/auth/view_models/auth_view_model.dart';
import 'package:superxsecret/ui/features/auth/views/lock_screen_view.dart';
import 'package:superxsecret/ui/features/auth/widgets/zero_knowledge_disclaimer_sheet.dart';
import 'package:superxsecret/ui/features/vault/view_models/vault_view_model.dart';
import 'package:superxsecret/ui/features/vault/views/vault_dashboard_view.dart';

void main() {
  group('Phase 4: Zero-Knowledge Onboarding & Clean Vault Production Tests', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    test('Fresh production vault starts with 0 items (Clean Vault)', () async {
      final rustService = RustVaultFfiService(includeDemoData: false);
      final repo = VaultRepository(
        rustFfiService: rustService,
        osHardeningService: OsHardeningService(),
      );

      await repo.setupDualSlotVault(
        mainPassword: 'CleanVaultPassword1!',
        secondaryPassword: 'CleanDecoyPin1234',
      );

      final items = await repo.fetchVaultSummaries();
      expect(items, isEmpty);

      // Decoy vault must also be completely empty
      repo.lockVaultImmediately();
      await repo.unlockVault('CleanDecoyPin1234');
      final decoyItems = await repo.fetchVaultSummaries();
      expect(decoyItems, isEmpty);
    });

    test('Load Sample Demo Data populates items on demand and decrypts cleanly',
        () async {
      final rustService = RustVaultFfiService(includeDemoData: false);
      final repo = VaultRepository(
        rustFfiService: rustService,
        osHardeningService: OsHardeningService(),
      );

      await repo.setupDualSlotVault(
        mainPassword: 'ProductionPass#2026',
        secondaryPassword: 'ProductionDecoyPin',
      );
      expect(await repo.fetchVaultSummaries(), isEmpty);

      // Load sample demo items on demand
      await repo.loadSampleDemoData();
      final loadedItems = await repo.fetchVaultSummaries();
      expect(loadedItems.length, equals(3));
      expect(loadedItems.map((e) => e.topic),
          containsAll(['ProtonMail', 'KBank Card', 'Crypto Seed']));

      // Reveal decrypts the demo secret
      final revealed = await repo.revealSecretPayloadJit('topic-main-01');
      expect(revealed.secretText, contains('user@proton.me'));
    });

    test('AuthViewModel manages and persists disclaimer acknowledgment in SharedPreferences',
        () async {
      final repo = VaultRepository(
        rustFfiService: RustVaultFfiService(),
        osHardeningService: OsHardeningService(),
      );
      final authVm1 = AuthViewModel(vaultRepository: repo);
      await authVm1.initializeSecurityCheck();
      expect(authVm1.hasAcknowledgedDisclaimer, isFalse);

      await authVm1.acknowledgeDisclaimer();
      expect(authVm1.hasAcknowledgedDisclaimer, isTrue);

      // Subsequent session loads persisted status
      final authVm2 = AuthViewModel(vaultRepository: repo);
      await authVm2.initializeSecurityCheck();
      expect(authVm2.hasAcknowledgedDisclaimer, isTrue);
    });

    testWidgets('ZeroKnowledgeDisclaimerSheet renders all 4 pillars and enforces checkbox',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var acknowledgedCalled = false;

      await tester.pumpWidget(
        AppLanguageScope(
          controller: AppLanguageController()..setLanguage(AppLanguage.english),
          child: MaterialApp(
            home: Scaffold(
              body: ZeroKnowledgeDisclaimerSheet(
                onAcknowledged: () => acknowledgedCalled = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check header and 4 pillars
      expect(find.text('Zero-Knowledge Security Notice'), findsOneWidget);
      expect(find.text('100% Offline & Zero Network'), findsOneWidget);
      expect(find.text('Zero Password Recovery'), findsOneWidget);
      expect(find.text('Regular Offline Backups'), findsOneWidget);
      expect(find.text('Dual-Vault Plausible Deniability'), findsOneWidget);

      // Proceed button is disabled initially
      final proceedButtonFinder = find.widgetWithText(
        ElevatedButton,
        'I Understand & Proceed',
      );
      expect(proceedButtonFinder, findsOneWidget);
      final buttonWidget = tester.widget<ElevatedButton>(proceedButtonFinder);
      expect(buttonWidget.onPressed, isNull);

      // Check acknowledgment checkbox
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // Proceed button is now enabled
      final enabledButton = tester.widget<ElevatedButton>(proceedButtonFinder);
      expect(enabledButton.onPressed, isNotNull);

      await tester.tap(proceedButtonFinder);
      await tester.pumpAndSettle();
      expect(acknowledgedCalled, isTrue);
    });

    testWidgets('Empty Vault renders clean state with Load Demo Data button and action',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = VaultRepository(
        rustFfiService: RustVaultFfiService(includeDemoData: false),
        osHardeningService: OsHardeningService(),
      );
      await repo.setupDualSlotVault(
        mainPassword: 'MyCleanPassword#1',
        secondaryPassword: 'MyDecoyPin1234',
      );

      final viewModel = VaultViewModel(vaultRepository: repo);
      await viewModel.loadVaultSummaries();

      await tester.pumpWidget(
        AppLanguageScope(
          controller: AppLanguageController()..setLanguage(AppLanguage.english),
          child: MaterialApp(
            home: VaultDashboardView(
              viewModel: viewModel,
              onLockRequested: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Clean Vault Empty State
      expect(find.text('Your Vault is Empty'), findsOneWidget);
      expect(find.textContaining('Tap "New" above'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Load Demo Data'), findsOneWidget);

      // Tap Load Demo Data button
      await tester.tap(find.widgetWithText(OutlinedButton, 'Load Demo Data'));
      await tester.pumpAndSettle();

      // Confirmation dialog appears
      expect(find.text('Load Sample Demo Data?'), findsOneWidget);
      final confirmBtn = find.widgetWithText(FilledButton, 'Load Demo Data');
      expect(confirmBtn, findsOneWidget);

      await tester.tap(confirmBtn);
      // Wait for Isolate.run Argon2id derivation to complete across threads
      await tester.runAsync(() async {
        final stopAt = DateTime.now().add(const Duration(seconds: 4));
        while (viewModel.filteredItems.isEmpty &&
            DateTime.now().isBefore(stopAt)) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      });
      await tester.pumpAndSettle();

      // Dashboard now contains sample items!
      expect(find.text('ProtonMail'), findsOneWidget);
      expect(find.text('KBank Card'), findsOneWidget);
      expect(find.text('Crypto Seed'), findsOneWidget);
    });

    testWidgets('LockScreenView on uninitialized vault shows Setup mode and Security Notice',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = VaultRepository(
        rustFfiService: RustVaultFfiService(includeDemoData: false),
        osHardeningService: OsHardeningService(),
      );
      final authVm = AuthViewModel(vaultRepository: repo);

      await tester.pumpWidget(
        AppLanguageScope(
          controller: AppLanguageController()..setLanguage(AppLanguage.english),
          child: MaterialApp(
            home: LockScreenView(
              viewModel: authVm,
              onVaultUnlocked: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // On uninitialized vault, setup mode is active
      expect(find.text('Security Notice'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsOneWidget);
      expect(find.textContaining('zero-knowledge offline vault'), findsOneWidget);
    });
  });
}
