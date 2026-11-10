import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superxsecret/data/repositories/vault_repository.dart';
import 'package:superxsecret/data/services/os_hardening_service.dart';
import 'package:superxsecret/data/services/rust_vault_ffi_service.dart';
import 'package:superxsecret/ui/core/controllers/license_controller.dart';
import 'package:superxsecret/ui/core/localization/app_localizations.dart';
import 'package:superxsecret/ui/features/vault/view_models/vault_view_model.dart';
import 'package:superxsecret/ui/features/vault/views/pro_upgrade_sheet.dart';
import 'package:superxsecret/ui/features/vault/views/vault_dashboard_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // Helper to generate a valid signed key for tests
  Future<String> generateTestKey({
    required String owner,
    String plan = 'lifetime',
  }) async {
    const privateKeyHex =
        '47083cf57f5a9cbb74207f9b0093e0f6b8cf9463491ae91d6a23a1af5f65256e';
    const publicKeyHex =
        '12f21eaea1309b4b9b37fba2dd9af60ccd8a3ca1d1744623c796a9c668a8b0eb';

    final payload = {
      'app': 'superxsecret',
      'owner': owner,
      'plan': plan,
      'issued_at': DateTime.now().toUtc().toIso8601String(),
    };

    final payloadBytes = utf8.encode(jsonEncode(payload));
    final payloadB64 = base64Url.encode(payloadBytes).replaceAll('=', '');

    final privBytes = <int>[];
    for (var i = 0; i < privateKeyHex.length; i += 2) {
      privBytes.add(int.parse(privateKeyHex.substring(i, i + 2), radix: 16));
    }
    final pubBytes = <int>[];
    for (var i = 0; i < publicKeyHex.length; i += 2) {
      pubBytes.add(int.parse(publicKeyHex.substring(i, i + 2), radix: 16));
    }

    final algorithm = Ed25519();
    final keyPair = SimpleKeyPairData(
      privBytes,
      publicKey: SimplePublicKey(pubBytes, type: KeyPairType.ed25519),
      type: KeyPairType.ed25519,
    );

    final signature = await algorithm.sign(payloadBytes, keyPair: keyPair);
    final signatureB64 = base64Url.encode(signature.bytes).replaceAll('=', '');

    return 'SXS-$payloadB64.$signatureB64';
  }

  group('LicenseController Unit Tests', () {
    test('Default status is Free Tier with 3 max items (Text only)', () async {
      final controller = LicenseController();
      await controller.loadLicense();
      expect(controller.isPro, isFalse);
      expect(LicenseController.maxFreeItems, 3);
      expect(controller.isCategoryAllowed('text'), isTrue);
      expect(controller.isCategoryAllowed('image'), isFalse);
      expect(controller.isCategoryAllowed('audio'), isFalse);
      expect(controller.isCategoryAllowed('video'), isFalse);
      expect(controller.isCategoryAllowed('file'), isFalse);
      expect(controller.licenseOwner, isNull);
    });

    test('Rejects invalid or forged license keys', () async {
      final controller = LicenseController();
      await controller.loadLicense();

      expect(await controller.activateLicense('INVALID-KEY'), isFalse);
      expect(await controller.activateLicense('SXS-fake.signature'), isFalse);
      expect(controller.isPro, isFalse);
    });

    test('Verifies and activates valid Ed25519 signed License Key', () async {
      final controller = LicenseController();
      await controller.loadLicense();

      final validKey = await generateTestKey(owner: 'vip@superxlab.com');
      final result = await controller.activateLicense(validKey);

      expect(result, isTrue);
      expect(controller.isPro, isTrue);
      expect(controller.licenseOwner, 'vip@superxlab.com');
      expect(controller.licensePlan, 'lifetime');

      // Verify persistence
      final reloaded = LicenseController();
      await reloaded.loadLicense();
      expect(reloaded.isPro, isTrue);
      expect(reloaded.licenseOwner, 'vip@superxlab.com');

      // Test deactivation
      await reloaded.deactivateLicense();
      expect(reloaded.isPro, isFalse);
    });
  });

  group('ProUpgradeSheet Widget Tests', () {
    testWidgets('Renders free tier status and activates with valid key',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = LicenseController();
      await controller.loadLicense();

      await tester.pumpWidget(
        AppLanguageScope(
          controller: AppLanguageController()..setLanguage(AppLanguage.english),
          child: MaterialApp(
            home: Scaffold(
              body: ProUpgradeSheet(
                licenseController: controller,
                currentItemCount: 2,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Upgrade to SuperXSecret Pro'), findsOneWidget);
      expect(find.text('2 / 3 items'), findsOneWidget);
      expect(find.text('Unlimited Vault Records'), findsOneWidget);

      final validKey = await generateTestKey(owner: 'buyer@test.com');
      await tester.enterText(find.byType(TextField), validKey);
      await tester.pump();

      await tester.tap(find.text('Activate License'));
      await tester.pumpAndSettle();

      expect(controller.isPro, isTrue);
    });
  });

  group('VaultDashboardView Free vs Pro Integration Tests', () {
    testWidgets('Header displays PRO badge and opens ProUpgradeSheet',
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
        mainPassword: 'MySecurePassword#1',
        secondaryPassword: 'MySecondaryDecoy123',
      );

      final viewModel = VaultViewModel(vaultRepository: repo);
      await viewModel.loadVaultSummaries();

      final licenseController = LicenseController();
      await licenseController.loadLicense();

      await tester.pumpWidget(
        AppLanguageScope(
          controller: AppLanguageController()..setLanguage(AppLanguage.english),
          child: MaterialApp(
            home: VaultDashboardView(
              viewModel: viewModel,
              licenseController: licenseController,
              onLockRequested: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find PRO / UPGRADE badge in header
      expect(find.text('UPGRADE'), findsOneWidget);
      await tester.tap(find.text('UPGRADE'));
      await tester.pumpAndSettle();

      // Pro sheet appears
      expect(find.text('Upgrade to SuperXSecret Pro'), findsOneWidget);
    });

    testWidgets('Free tier restricts adding non-text categories directly',
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
        mainPassword: 'MySecurePassword#1',
        secondaryPassword: 'MySecondaryDecoy123',
      );

      final viewModel = VaultViewModel(vaultRepository: repo);
      await viewModel.loadVaultSummaries();

      final licenseController = LicenseController();
      await licenseController.loadLicense();

      await tester.pumpWidget(
        AppLanguageScope(
          controller: AppLanguageController()..setLanguage(AppLanguage.english),
          child: MaterialApp(
            home: VaultDashboardView(
              viewModel: viewModel,
              licenseController: licenseController,
              onLockRequested: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Image tab (index 1)
      await tester.tap(find.byIcon(Icons.image_outlined));
      await tester.pumpAndSettle();

      // Tap + button while on image tab -> Pro upgrade sheet opens
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Upgrade to SuperXSecret Pro'), findsOneWidget);
    });
  });
}
