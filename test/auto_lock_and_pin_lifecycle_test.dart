import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superxsecret/data/repositories/vault_repository.dart';
import 'package:superxsecret/data/services/os_hardening_service.dart';
import 'package:superxsecret/data/services/rust_vault_ffi_service.dart';
import 'package:superxsecret/ui/core/controllers/auto_lock_controller.dart';
import 'package:superxsecret/ui/core/localization/app_localizations.dart';
import 'package:superxsecret/ui/features/auth/views/quick_pin_lock_view.dart';
import 'package:superxsecret/ui/features/vault/view_models/vault_view_model.dart';
import 'package:superxsecret/ui/features/vault/views/vault_dashboard_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AutoLockController Unit Tests', () {
    test('Default settings are 1 minute inactivity and 1 minute screen off timeout', () async {
      final controller = AutoLockController();
      await controller.loadSettings();
      expect(controller.inactivityTimeoutMinutes, 1);
      expect(controller.screenOffTimeoutMinutes, 1);
      expect(controller.timeoutMinutes, 1);
      expect(controller.isPinConfigured, isFalse);
      expect(controller.isSoftLocked, isFalse);
    });

    test('Separately configuring inactivity and screen off timeouts', () async {
      final controller = AutoLockController();
      await controller.loadSettings();

      await controller.setInactivityTimeoutMinutes(3);
      await controller.setScreenOffTimeoutMinutes(5);

      expect(controller.inactivityTimeoutMinutes, 3);
      expect(controller.screenOffTimeoutMinutes, 5);

      // Verify persistence into SharedPreferences
      final reloadedController = AutoLockController();
      await reloadedController.loadSettings();
      expect(reloadedController.inactivityTimeoutMinutes, 3);
      expect(reloadedController.screenOffTimeoutMinutes, 5);
    });

    test('Screen off timeout set to 0 triggers immediate hard logout on pause', () async {
      final controller = AutoLockController();
      await controller.loadSettings();
      await controller.setQuickPin('1234');
      await controller.setScreenOffTimeoutMinutes(0); // Immediate

      var immediateHardLockCalled = false;
      controller.onAppPaused(
        onImmediateHardLock: () => immediateHardLockCalled = true,
      );

      expect(immediateHardLockCalled, isTrue);
    });

    test('Configuring and verifying PIN with CSPRNG Salt + SHA-256', () async {
      final controller = AutoLockController();
      await controller.loadSettings();

      await controller.setQuickPin('1234');
      expect(controller.isPinConfigured, isTrue);

      var hardLogoutCalled = false;

      // Verify wrong PIN fails and decrements attempts
      final wrongResult = await controller.verifyAndUnlockWithPin(
        '9999',
        onHardLogout: () => hardLogoutCalled = true,
      );
      expect(wrongResult, isFalse);
      expect(controller.pinAttemptsRemaining, 2);
      expect(hardLogoutCalled, isFalse);

      // Verify correct PIN succeeds and resets attempts
      final correctResult = await controller.verifyAndUnlockWithPin(
        '1234',
        onHardLogout: () => hardLogoutCalled = true,
      );
      expect(correctResult, isTrue);
      expect(controller.pinAttemptsRemaining, 3);
      expect(controller.isSoftLocked, isFalse);
    });

    test('Failing PIN 3 times triggers hard logout immediately', () async {
      final controller = AutoLockController();
      await controller.loadSettings();
      await controller.setQuickPin('5678');

      var hardLogoutCount = 0;
      void onHardLogout() => hardLogoutCount++;

      await controller.verifyAndUnlockWithPin('0000', onHardLogout: onHardLogout);
      expect(controller.pinAttemptsRemaining, 2);
      expect(hardLogoutCount, 0);

      await controller.verifyAndUnlockWithPin('0000', onHardLogout: onHardLogout);
      expect(controller.pinAttemptsRemaining, 1);
      expect(hardLogoutCount, 0);

      await controller.verifyAndUnlockWithPin('0000', onHardLogout: onHardLogout);
      expect(controller.pinAttemptsRemaining, 3); // Reset after hard logout
      expect(hardLogoutCount, 1); // Hard logout triggered!
    });

    test('Background pause with PIN configured triggers Soft Lock within timeout', () async {
      final controller = AutoLockController();
      await controller.loadSettings();
      await controller.setQuickPin('4321');
      await controller.setTimeoutMinutes(2);

      var hardLogoutCalled = false;
      controller.onAppPaused(onImmediateHardLock: () => hardLogoutCalled = true);

      // Should be soft-locked, not hard logout
      expect(controller.isSoftLocked, isTrue);
      expect(hardLogoutCalled, isFalse);

      // Resuming within timeout preserves soft lock for PIN entry
      controller.onAppResumed(onHardLogout: () => hardLogoutCalled = true);
      expect(controller.isSoftLocked, isTrue);
      expect(hardLogoutCalled, isFalse);
    });

    test('Removing PIN disables quick PIN lock', () async {
      final controller = AutoLockController();
      await controller.loadSettings();
      await controller.setQuickPin('1111');
      expect(controller.isPinConfigured, isTrue);

      await controller.removeQuickPin();
      expect(controller.isPinConfigured, isFalse);
      expect(controller.isSoftLocked, isFalse);
    });
  });

  group('QuickPinLockView Widget Tests', () {
    testWidgets('Renders Scrambled Keypad and unlocks on correct PIN', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = AutoLockController();
      addTearDown(controller.dispose);
      await controller.loadSettings();
      await controller.setQuickPin('2580');

      var hardLogoutCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: QuickPinLockView(
            autoLockController: controller,
            onHardLogoutRequested: () => hardLogoutCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quick PIN Unlock'), findsOneWidget);
      expect(find.byIcon(Icons.dialpad_rounded), findsOneWidget);

      // Tap '2', '5', '8', '0'
      for (final digit in ['2', '5', '8', '0']) {
        final digitFinder = find.widgetWithText(ElevatedButton, digit);
        expect(digitFinder, findsOneWidget);
        await tester.tap(digitFinder);
        await tester.pump();
      }

      // Tap Unlock button
      final unlockBtn = find.widgetWithText(FilledButton, 'Unlock');
      expect(unlockBtn, findsOneWidget);
      await tester.tap(unlockBtn);
      await tester.pumpAndSettle();

      expect(controller.isSoftLocked, isFalse);
      expect(hardLogoutCalled, isFalse);
      controller.cancelTimers();
    });

    testWidgets('Tapping Logout with Master Password calls onHardLogoutRequested', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = AutoLockController();
      await controller.loadSettings();
      await controller.setQuickPin('9999');

      var hardLogoutCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: QuickPinLockView(
            autoLockController: controller,
            onHardLogoutRequested: () => hardLogoutCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final logoutBtn = find.text('Logout with Master Password');
      expect(logoutBtn, findsOneWidget);
      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();

      expect(hardLogoutCalled, isTrue);
    });
  });

  group('VaultDashboardView PIN & Auto-Lock Settings Integration', () {
    testWidgets('Tapping PIN icon opens Auto-Lock Settings BottomSheet', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = VaultRepository(
        rustFfiService: RustVaultFfiService(includeDemoData: false),
        osHardeningService: OsHardeningService(),
      );
      await repo.setupDualSlotVault(
        mainPassword: 'MyStrongMasterPassword1!',
        secondaryPassword: 'MySecondaryDecoy1234',
      );

      final viewModel = VaultViewModel(vaultRepository: repo);
      await viewModel.loadVaultSummaries();

      final autoLockController = AutoLockController();
      await autoLockController.loadSettings();

      await tester.pumpWidget(
        AppLanguageScope(
          controller: AppLanguageController()..setLanguage(AppLanguage.english),
          child: MaterialApp(
            home: VaultDashboardView(
              viewModel: viewModel,
              autoLockController: autoLockController,
              onLockRequested: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find PIN Icon in header
      final pinIconBtn = find.byTooltip('PIN & Auto-Lock Settings');
      expect(pinIconBtn, findsOneWidget);

      await tester.tap(pinIconBtn);
      await tester.pumpAndSettle();

      // Settings bottom sheet is displayed with separated configs
      expect(find.text('PIN & Auto-Lock Settings'), findsOneWidget);
      expect(find.text('In-App Inactivity Timeout'), findsOneWidget);
      expect(find.text('Screen Off / Background Timeout'), findsOneWidget);
      expect(find.text('Immediate'), findsOneWidget);
      expect(find.text('Off (Never)'), findsOneWidget);
      expect(find.text('Set PIN'), findsOneWidget);

      // Verify Load Demo Data button does NOT exist anywhere
      expect(find.text('Load Demo Data'), findsNothing);
      expect(find.text('Load Sample Demo Data?'), findsNothing);
    });
  });
}
