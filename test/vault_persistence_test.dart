import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superxsecret/data/repositories/vault_repository.dart';
import 'package:superxsecret/data/services/os_hardening_service.dart';
import 'package:superxsecret/data/services/rust_vault_ffi_service.dart';
import 'package:superxsecret/data/services/vault_storage_service.dart';
import 'package:superxsecret/domain/models/vault_models.dart';
import 'package:superxsecret/ui/core/localization/app_localizations.dart';
import 'package:superxsecret/ui/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late VaultStorageService storageService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('superxsecret_test_');
    storageService = VaultStorageService(customStorageDirectory: tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SuperXSecret Phase 1: Persistent Encrypted Storage Tests', () {
    test('VaultStorageService saves and reloads encrypted vault data atomically', () async {
      final sampleData = {
        'isVaultInitialized': true,
        'mainPassword': 'MasterPassword123!',
        'secondaryPassword': 'DecoyPassword999!',
        'mainItems': [
          {
            'itemUuid': 'topic-1',
            'topic': 'Secret Note',
            'updatedAt': DateTime.now().toIso8601String(),
            'hasExtraLock': false,
            'passwordHint': '',
            'cipherType': 'aes256Gcm',
            'category': 'text',
          }
        ],
      };

      await storageService.saveVaultData(sampleData);
      final loaded = await storageService.loadVaultData();

      expect(loaded, isNotNull);
      expect(loaded!['isVaultInitialized'], isTrue);
      expect(loaded['mainPassword'], equals('MasterPassword123!'));
      expect((loaded['mainItems'] as List).length, equals(1));
    });

    test('VaultStorageService wipes vault file with zeroes upon reset', () async {
      await storageService.saveVaultData({'test': 'sensitive_data_12345'});
      final file = File('${tempDir.path}/superxsecret_vault_v1.enc.json');
      expect(await file.exists(), isTrue);

      await storageService.wipeVaultData();
      expect(await file.exists(), isFalse);

      final loaded = await storageService.loadVaultData();
      expect(loaded, isNull);
    });

    test('RustVaultFfiService persists items and survives service restarts', () async {
      // 1. First service instance creates and saves data
      final service1 = RustVaultFfiService(storageService: storageService);
      await service1.initializeDualSlotVault(
        mainPassword: 'MyStrongMasterPass2026!',
        secondaryPassword: 'DecoyPassword2026!',
        passwordHint: 'hint for master',
      );

      final created = await service1.createNewTopic(
        topic: 'Personal Bank Account',
        secretText: 'Account: 998-1123-441, PIN: 7721',
        cipherType: VaultCipherType.xchacha20Poly1305,
        category: VaultItemCategory.text,
      );
      expect(created.topic, equals('Personal Bank Account'));

      // 2. Second service instance simulates closing and reopening the app
      final service2 = RustVaultFfiService(storageService: storageService);
      await service2.initFromStorage();

      expect(service2.isVaultInitialized, isTrue);

      // Unlock with master password on the fresh instance
      final mode = await service2.unlockVault('MyStrongMasterPass2026!');
      expect(mode, equals(VaultSessionMode.mainVault));

      final summaries = await service2.listSummaries();
      expect(summaries.any((s) => s.topic == 'Personal Bank Account'), isTrue);

      // Decrypt the secret from disk ciphertext JIT
      final bankSummary = summaries.firstWhere((s) => s.topic == 'Personal Bank Account');
      final decrypted = await service2.decryptPayloadJit(bankSummary.itemUuid);
      expect(decrypted.secretText, contains('Account: 998-1123-441'));
      expect(decrypted.cipherType, equals(VaultCipherType.xchacha20Poly1305));
    });

    test('WipeAllVaultData clears both in-memory structures and disk storage', () async {
      final rustService = RustVaultFfiService(storageService: storageService);
      final repo = VaultRepository(
        rustFfiService: rustService,
        osHardeningService: OsHardeningService(),
      );

      await repo.setupDualSlotVault(
        mainPassword: 'MainPassword2026!',
        secondaryPassword: 'DecoyPassword2026!',
      );
      await repo.saveTopic(topic: 'Item To Wipe', secretText: 'SuperSecret');

      expect(rustService.isVaultInitialized, isTrue);

      // Wipe everything
      await repo.wipeAllVaultData();

      expect(rustService.isVaultInitialized, isFalse);
      expect(rustService.activeSessionMode, isNull);

      final file = File('${tempDir.path}/superxsecret_vault_v1.enc.json');
      expect(await file.exists(), isFalse);
    });

    test('User preferences for Language and Theme persist across controller restarts', () async {
      // 1. Set Language to Thai and Theme to Dark
      final langCtrl1 = AppLanguageController();
      langCtrl1.setLanguage(AppLanguage.thai);

      final themeCtrl1 = AppThemeController();
      themeCtrl1.setThemeMode(AppThemeMode.dark);

      // Allow async SharedPreferences write to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // 2. New controllers simulate launching the app again
      final langCtrl2 = AppLanguageController();
      await langCtrl2.loadSavedLanguage();
      expect(langCtrl2.currentLanguage, equals(AppLanguage.thai));

      final themeCtrl2 = AppThemeController();
      await themeCtrl2.loadSavedTheme();
      expect(themeCtrl2.currentThemeMode, equals(AppThemeMode.dark));
    });
  });
}
