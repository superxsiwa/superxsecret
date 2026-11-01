import 'package:flutter_test/flutter_test.dart';
import 'package:superxsecret/data/repositories/vault_repository.dart';
import 'package:superxsecret/data/services/os_hardening_service.dart';
import 'package:superxsecret/data/services/rust_vault_ffi_service.dart';
import 'package:superxsecret/domain/models/vault_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SuperXSecret 5-Cipher Multi-Algorithm Encryption & Decryption Tests',
      () {
    late RustVaultFfiService rustFfiService;
    late VaultRepository repository;

    setUp(() async {
      rustFfiService = RustVaultFfiService();
      repository = VaultRepository(
        rustFfiService: rustFfiService,
        osHardeningService: OsHardeningService(),
      );
      await repository.unlockVault('SuperSecret#2026');
    });

    for (final cipher in VaultCipherType.values) {
      test(
          'Topic created with ${cipher.badgeLabel} encrypts and decrypts with the exact same cipher',
          () async {
        final topicName = 'Secret-${cipher.name}';
        final secretText = 'TopSecret-Payload-For-${cipher.badgeLabel}';

        final summary = await repository.saveTopic(
          topic: topicName,
          secretText: secretText,
          cipherType: cipher,
        );

        expect(summary.cipherType, equals(cipher));
        expect(summary.topic, equals(topicName));

        // Verify JIT Decryption uses the matching cipher and decrypts cleanly
        final decrypted =
            await repository.revealSecretPayloadJit(summary.itemUuid);
        expect(decrypted.secretText, equals(secretText));
        expect(decrypted.cipherType, equals(cipher));
      });
    }

    test('Extra Lock works seamlessly across all 5 ciphers', () async {
      for (final cipher in VaultCipherType.values) {
        final topic = 'ExtraLock-${cipher.name}';
        final secret = 'SensitiveData-${cipher.badgeLabel}';
        const itemPwd = 'ItemPassword#999';

        final summary = await repository.saveTopic(
          topic: topic,
          secretText: secret,
          hasExtraLock: true,
          itemPassword: itemPwd,
          passwordHint: 'Hint-${cipher.name}',
          cipherType: cipher,
        );

        expect(summary.hasExtraLock, isTrue);
        expect(summary.cipherType, equals(cipher));

        // Attempting to reveal without password throws ItemLockedException
        expect(
          () => repository.revealSecretPayloadJit(summary.itemUuid),
          throwsA(isA<ItemLockedException>()),
        );

        // Revealing with correct item password succeeds
        final revealed = await repository.revealSecretPayloadJit(
          summary.itemUuid,
          itemPassword: itemPwd,
        );
        expect(revealed.secretText, equals(secret));
        expect(revealed.cipherType, equals(cipher));
      }
    });

    test('.sxsi export and import preserves original cipher type', () async {
      final summary = await repository.saveTopic(
        topic: 'DualShare',
        secretText: 'Dual-Cipher-Secret-1234',
        cipherType: VaultCipherType.dualCipher,
      );

      final sxsiPacket = await repository.exportSingleItemSxsi(
        itemUuid: summary.itemUuid,
        filePassword: 'SharePassword#123',
      );

      final imported = await repository.importSingleItemSxsi(
        sxsiPacket: sxsiPacket,
        filePassword: 'SharePassword#123',
      );

      expect(imported.topic, equals('DualShare'));
      expect(imported.cipherType, equals(VaultCipherType.dualCipher));

      final revealed =
          await repository.revealSecretPayloadJit(imported.itemUuid);
      expect(revealed.secretText, equals('Dual-Cipher-Secret-1234'));
      expect(revealed.cipherType, equals(VaultCipherType.dualCipher));
    });

    test('.sxs full backup and restore preserves all 5 cipher types', () async {
      for (final cipher in VaultCipherType.values) {
        await repository.saveTopic(
          topic: 'Backup-${cipher.name}',
          secretText: 'Payload-${cipher.name}',
          cipherType: cipher,
        );
      }

      final backupBytes = await repository.exportSxsBackup(
        verifyMasterPassword: 'SuperSecret#2026',
        backupEncryptionPassword: 'BackupPassword#777',
      );

      // Restore into new service
      final newService = RustVaultFfiService();
      final newRepo = VaultRepository(
        rustFfiService: newService,
        osHardeningService: OsHardeningService(),
      );
      await newRepo.unlockVault('SuperSecret#2026');

      await newRepo.restoreSxsBackup(
        backupBytes: backupBytes,
        backupFilePassword: 'BackupPassword#777',
      );

      final restoredSummaries = await newRepo.fetchVaultSummaries();
      for (final cipher in VaultCipherType.values) {
        final item = restoredSummaries
            .firstWhere((s) => s.topic == 'Backup-${cipher.name}');
        expect(item.cipherType, equals(cipher));

        final revealed = await newRepo.revealSecretPayloadJit(item.itemUuid);
        expect(revealed.secretText, equals('Payload-${cipher.name}'));
        expect(revealed.cipherType, equals(cipher));
      }
    });
  });
}
