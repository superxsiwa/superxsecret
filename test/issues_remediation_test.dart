import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:superxsecret/data/services/rust_vault_ffi_service.dart';
import 'package:superxsecret/data/services/vault_storage_service.dart';
import 'package:superxsecret/domain/models/vault_models.dart';
import 'package:superxsecret/ui/core/localization/app_localizations.dart';

void main() {
  group('SuperXSecret Issues Remediation Suite (#1 - #6)', () {
    late VaultStorageService storage;
    late RustVaultFfiService ffi;

    setUp(() async {
      storage = VaultStorageService();
      ffi = RustVaultFfiService(storageService: storage);
      await ffi.initializeDualSlotVault(
        mainPassword: 'MainPassword#2026',
        secondaryPassword: 'DecoyPassword#2026',
        passwordHint: 'My Hint',
      );
    });

    test(
        'Issue #1: Preserves category, fileName and fileSize across Extra Lock modifications',
        () async {
      // 1. Create a non-text item (e.g. image)
      final rawBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final initialItem = await ffi.createNewTopic(
        topic: 'Secret Passport Photo',
        secretText: 'Passport Note',
        category: VaultItemCategory.image,
        fileName: 'passport.png',
        fileSizeBytes: 8,
        mimeType: 'image/png',
        rawBytes: rawBytes,
      );

      expect(initialItem.category, equals(VaultItemCategory.image));
      expect(initialItem.fileName, equals('passport.png'));
      expect(initialItem.fileSizeBytes, equals(8));

      // 2. Add Extra Lock -> verify metadata is preserved
      await ffi.setItemExtraLock(
        itemUuid: initialItem.itemUuid,
        newItemPassword: 'ExtraLockPin#123',
        passwordHint: 'PIN Hint',
      );

      var summaries = await ffi.listSummaries();
      var updated = summaries.firstWhere((s) => s.itemUuid == initialItem.itemUuid);
      expect(updated.category, equals(VaultItemCategory.image),
          reason: 'Category must remain image after setItemExtraLock');
      expect(updated.fileName, equals('passport.png'),
          reason: 'FileName must remain passport.png after setItemExtraLock');
      expect(updated.fileSizeBytes, equals(8),
          reason: 'FileSize must remain 8 after setItemExtraLock');
      expect(updated.hasExtraLock, isTrue);

      // 3. Remove Extra Lock -> verify metadata is still preserved
      await ffi.removeItemExtraLock(
        itemUuid: initialItem.itemUuid,
        itemPassword: 'ExtraLockPin#123',
      );

      summaries = await ffi.listSummaries();
      updated = summaries.firstWhere((s) => s.itemUuid == initialItem.itemUuid);
      expect(updated.category, equals(VaultItemCategory.image),
          reason: 'Category must remain image after removeItemExtraLock');
      expect(updated.fileName, equals('passport.png'),
          reason: 'FileName must remain passport.png after removeItemExtraLock');
      expect(updated.fileSizeBytes, equals(8),
          reason: 'FileSize must remain 8 after removeItemExtraLock');
      expect(updated.hasExtraLock, isFalse);

      // 4. Update Item Password -> verify metadata is still preserved
      await ffi.updateItemPassword(
        itemUuid: initialItem.itemUuid,
        currentItemPassword: 'MainPassword#2026',
      );

      summaries = await ffi.listSummaries();
      updated = summaries.firstWhere((s) => s.itemUuid == initialItem.itemUuid);
      expect(updated.category, equals(VaultItemCategory.image),
          reason: 'Category must remain image after updateItemPassword');
      expect(updated.fileName, equals('passport.png'),
          reason: 'FileName must remain passport.png after updateItemPassword');
      expect(updated.fileSizeBytes, equals(8),
          reason: 'FileSize must remain 8 after updateItemPassword');
    });

    test('Issue #2: Empty items list in storage properly clears memory on reload',
        () async {
      await ffi.createNewTopic(
        topic: 'Test Topic',
        secretText: 'Sample Secret',
      );

      var summaries = await ffi.listSummaries();
      expect(summaries.length, equals(1));

      // Simulate on-disk storage being updated with 0 items
      final storedData = await storage.loadVaultData();
      expect(storedData, isNotNull);
      storedData!['mainItems'] = <dynamic>[];
      await storage.saveVaultData(storedData);

      // Re-init from storage
      await ffi.initFromStorage();
      summaries = await ffi.listSummaries();
      expect(summaries.isEmpty, isTrue,
          reason: 'Memory summaries must be cleared when stored items are empty');
    });

    test(
        'Issue #3: exportSxsEncryptedContainer rejects wrong slot password in active session',
        () async {
      // Currently in Main Vault session
      expect(ffi.activeSessionMode, equals(VaultSessionMode.mainVault));

      // Attempting to export Main Vault using Decoy Password must fail
      expect(
        () => ffi.exportSxsEncryptedContainer(
          verifyMasterPassword: 'DecoyPassword#2026',
          backupEncryptionPassword: 'BackupFilePassword#1',
        ),
        throwsA(isA<StateError>()),
        reason: 'Decoy password must NOT unlock Main Vault backup export',
      );

      // Using correct Main Password succeeds
      final backupBytes = await ffi.exportSxsEncryptedContainer(
        verifyMasterPassword: 'MainPassword#2026',
        backupEncryptionPassword: 'BackupFilePassword#1',
      );
      expect(backupBytes, isNotEmpty);

      // Unlock Secondary Vault (Decoy)
      await ffi.unlockVault('DecoyPassword#2026');
      expect(ffi.activeSessionMode, equals(VaultSessionMode.secondaryVault));

      // Attempting to export Secondary Vault using Main Password must fail
      expect(
        () => ffi.exportSxsEncryptedContainer(
          verifyMasterPassword: 'MainPassword#2026',
          backupEncryptionPassword: 'BackupFilePassword#1',
        ),
        throwsA(isA<StateError>()),
        reason: 'Main password must NOT unlock Secondary Vault backup export',
      );

      // Using correct Decoy Password succeeds
      final secBackup = await ffi.exportSxsEncryptedContainer(
        verifyMasterPassword: 'DecoyPassword#2026',
        backupEncryptionPassword: 'BackupFilePassword#1',
      );
      expect(secBackup, isNotEmpty);
    });

    test('Issue #5: Thai localization includes new string entries', () {
      final th = AppStrings.thai;
      expect(th.itemPasswordMinLength, contains('อย่างน้อย 6'));
      expect(th.itemPasswordsDoNotMatch, contains('ไม่ตรงกัน'));
      expect(th.passwordHintRequired, contains('คำใบ้'));
      expect(th.incorrectItemPassword, contains('ไม่ถูกต้อง'));
      expect(th.incorrectPassword, contains('ไม่ถูกต้อง'));
      expect(th.backupRestoredSuccess, contains('เรียบร้อย'));
      expect(th.compromisedDeviceWarning, contains('ความปลอดภัย'));
      expect(th.topicNameRequired, contains('ชื่อรายการ'));
      expect(th.topicNameAndSecretRequired, contains('ข้อมูลลับ'));
    });
  });
}
