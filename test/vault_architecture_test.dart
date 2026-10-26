import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superxsecret/data/repositories/vault_repository.dart';
import 'package:superxsecret/data/services/os_hardening_service.dart';
import 'package:superxsecret/data/services/rust_vault_ffi_service.dart';
import 'package:superxsecret/domain/models/vault_models.dart';
import 'package:superxsecret/ui/features/vault/view_models/vault_view_model.dart';
import 'package:superxsecret/ui/features/vault/views/vault_dashboard_view.dart';

void main() {
  group('SuperXSecret v1.5 Dual-Vault & Unified Topic Security Tests', () {
    late VaultRepository repository;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      repository = VaultRepository(
        rustFfiService: RustVaultFfiService(),
        osHardeningService: OsHardeningService(),
      );
    });

    test('Dual-Slot unlock isolates Main Vault (Slot A) from Secondary Vault (Slot B)', () async {
      await repository.setupDualSlotVault(
        mainPassword: 'MainVaultPassword#2026!',
        secondaryPassword: 'SecondaryVaultPin999',
      );

      // Unlock with Secondary Password -> opens Secondary Vault (Slot B) only
      final secondaryMode = await repository.unlockVault('SecondaryVaultPin999');
      expect(secondaryMode, equals(VaultSessionMode.secondaryVault));
      final secondaryItems = await repository.fetchVaultSummaries();
      expect(secondaryItems.length, equals(2));
      expect(secondaryItems.first.topic, equals('Netflix'));

      // Lock & unlock with Main Password -> opens Main Vault (Slot A)
      repository.lockVaultImmediately();
      final mainMode = await repository.unlockVault('MainVaultPassword#2026!');
      expect(mainMode, equals(VaultSessionMode.mainVault));
      final mainItems = await repository.fetchVaultSummaries();
      expect(mainItems.length, equals(3));
      expect(mainItems.first.topic, equals('ProtonMail'));
    });

    test('Unified Topic + Secret Text creation and JIT decryption work cleanly', () async {
      await repository.unlockVault('SuperSecret#2026');

      final summary = await repository.saveTopic(
        topic: 'GitHub Recovery',
        secretText: 'ghp_OfflineZeroKnowledgeToken2026',
      );

      expect(summary.topic, equals('GitHub Recovery'));

      final decoded = await repository.revealSecretPayloadJit(summary.itemUuid);
      expect(decoded.topic, equals('GitHub Recovery'));
      expect(decoded.secretText, equals('ghp_OfflineZeroKnowledgeToken2026'));
    });

    test('.sxsi single-item share verifies SXSI magic header and File Password', () async {
      await repository.setupDualSlotVault(
        mainPassword: 'MainVaultPassword#2026!',
        secondaryPassword: 'SecondaryVaultPin999',
      );
      await repository.unlockVault('MainVaultPassword#2026!');
      final mainItems = await repository.fetchVaultSummaries();

      final sxsiPacket = await repository.exportSingleItemSxsi(
        itemUuid: mainItems.first.itemUuid,
        filePassword: 'FriendShareKey#77',
      );
      expect(sxsiPacket.startsWith('SXSI1:'), isTrue);

      final rawBytes = base64Url.decode(
        base64Url.normalize(sxsiPacket.substring(6)),
      );
      // Verify "SXSI" (0x53, 0x58, 0x53, 0x49) magic header bytes
      expect(rawBytes.sublist(0, 4), equals([0x53, 0x58, 0x53, 0x49]));

      // Switch to Secondary Vault and import the shared .sxsi item
      repository.lockVaultImmediately();
      await repository.unlockVault('SecondaryVaultPin999');

      // Wrong password must fail authentication
      expect(
        () => repository.importSingleItemSxsi(
          sxsiPacket: sxsiPacket,
          filePassword: 'WrongPassword',
        ),
        throwsStateError,
      );

      // Correct File Password decodes and imports the topic
      final imported = await repository.importSingleItemSxsi(
        sxsiPacket: sxsiPacket,
        filePassword: 'FriendShareKey#77',
      );
      expect(imported.topic, equals('ProtonMail'));
    });

    test('.sxs full backup container begins with SXSV magic header bytes', () async {
      await repository.unlockVault('SuperSecret#2026');
      final sxsBytes = await repository.exportSxsBackup(
        verifyMasterPassword: 'SuperSecret#2026',
        backupEncryptionPassword: 'OfflineBackupPassword#1',
      );

      // Verify "SXSV" (0x53, 0x58, 0x53, 0x56) magic header
      expect(sxsBytes.sublist(0, 4), equals([0x53, 0x58, 0x53, 0x56]));
    });

    testWidgets('Unlocked VaultDashboardView renders identical UI without Main/Fake badges', (tester) async {
      await repository.unlockVault('Decoy1234');
      final viewModel = VaultViewModel(vaultRepository: repository);

      await tester.pumpWidget(
        MaterialApp(
          home: VaultDashboardView(
            viewModel: viewModel,
            onLockRequested: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('New'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.text('Import File'), findsOneWidget);
      expect(find.text('View'), findsWidgets);
      expect(find.text('Share'), findsWidgets);
      expect(find.text('Email'), findsNothing);
      expect(find.text('Bank'), findsNothing);
      expect(find.text('Crypto'), findsNothing);
      expect(find.textContaining('FAKE'), findsNothing);
      expect(find.textContaining('DECOY'), findsNothing);
    });
  });
}


