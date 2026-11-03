import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superxsecret/data/repositories/vault_repository.dart';
import 'package:superxsecret/data/services/os_hardening_service.dart';
import 'package:superxsecret/data/services/rust_vault_ffi_service.dart';
import 'package:superxsecret/domain/models/vault_models.dart';
import 'package:superxsecret/ui/core/localization/app_localizations.dart';
import 'package:superxsecret/ui/features/vault/view_models/vault_view_model.dart';
import 'package:superxsecret/ui/features/vault/views/vault_dashboard_view.dart';
import 'package:superxsecret/ui/features/auth/view_models/auth_view_model.dart';
import 'package:superxsecret/ui/features/auth/views/lock_screen_view.dart';

void main() {
  group('SuperXSecret v1.5 Dual-Vault & Unified Topic Security Tests', () {
    late VaultRepository repository;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      repository = VaultRepository(
        rustFfiService: RustVaultFfiService(includeDemoData: true),
        osHardeningService: OsHardeningService(),
      );
    });

    test(
        'Dual-Slot unlock isolates Main Vault (Slot A) from Secondary Vault (Slot B)',
        () async {
      await repository.setupDualSlotVault(
        mainPassword: 'MainVaultPassword#2026!',
        secondaryPassword: 'SecondaryVaultPin999',
      );

      // Unlock with Secondary Password -> opens Secondary Vault (Slot B) only
      final secondaryMode =
          await repository.unlockVault('SecondaryVaultPin999');
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

    test('Unified Topic + Secret Text creation and JIT decryption work cleanly',
        () async {
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

    test('Deleting a topic removes summary and encrypted secret cleanly',
        () async {
      await repository.unlockVault('SuperSecret#2026');

      final summary = await repository.saveTopic(
        topic: 'Temporary Item',
        secretText: 'temp secret to be deleted',
      );
      var items = await repository.fetchVaultSummaries();
      expect(items.any((item) => item.itemUuid == summary.itemUuid), isTrue);

      await repository.deleteTopic(summary.itemUuid);
      items = await repository.fetchVaultSummaries();
      expect(items.any((item) => item.itemUuid == summary.itemUuid), isFalse);
    });

    test('First reveal migrates a legacy item without decrypting it twice',
        () async {
      await repository.unlockVault('LegacyMigrationPassword1');

      final firstReveal =
          await repository.revealSecretPayloadJit('topic-main-01');
      expect(firstReveal.secretText, contains('user@proton.me'));

      final subsequentReveal =
          await repository.revealSecretPayloadJit('topic-main-01');
      expect(subsequentReveal.secretText, firstReveal.secretText);
    });

    test(
        'Changing passwords preserves items encrypted with their original password',
        () async {
      await repository.setupDualSlotVault(
        mainPassword: 'OriginalMainPassword#2026',
        secondaryPassword: 'OriginalSecondaryPassword#2026',
        passwordHint: 'First hint',
      );
      final item = await repository.saveTopic(
        topic: 'Old password item',
        secretText: 'still encrypted',
        passwordHint: 'Original hint',
      );

      await repository.setupDualSlotVault(
        mainPassword: 'ReplacementMainPassword#2026',
        secondaryPassword: 'ReplacementSecondaryPassword#2026',
        passwordHint: 'New hint',
      );

      final summaries = await repository.fetchVaultSummaries();
      expect(summaries.any((summary) => summary.itemUuid == item.itemUuid),
          isTrue);
      expect(
        summaries
            .singleWhere((summary) => summary.itemUuid == item.itemUuid)
            .passwordHint,
        'Original hint',
      );
      await expectLater(
        repository.revealSecretPayloadJit(item.itemUuid),
        throwsA(isA<VaultItemPasswordException>()),
      );

      final decoded = await repository.revealSecretPayloadJit(
        item.itemUuid,
        overridePassword: 'OriginalMainPassword#2026',
      );
      expect(decoded.secretText, 'still encrypted');
      expect(decoded.passwordHint, 'Original hint');

      await repository.updateItemPassword(
        itemUuid: item.itemUuid,
        currentItemPassword: 'OriginalMainPassword#2026',
      );
      final updated = await repository.revealSecretPayloadJit(item.itemUuid);
      expect(updated.secretText, 'still encrypted');
      expect(updated.passwordHint, 'New hint');
    });

    test(
        'Extra Lock requires its item password and survives vault password changes',
        () async {
      await repository.setupDualSlotVault(
        mainPassword: 'VaultPasswordOriginal#2026',
        secondaryPassword: 'SecondaryPasswordOriginal',
      );
      final item = await repository.saveTopic(
        topic: 'Extra Locked Item',
        secretText: 'extra private payload',
        hasExtraLock: true,
        itemPassword: 'DistinctItemPassword1',
        passwordHint: 'Favorite first pet',
      );

      expect(item.hasExtraLock, isTrue);
      expect(item.passwordHint, 'Favorite first pet');
      await expectLater(
        repository.revealSecretPayloadJit(item.itemUuid),
        throwsA(
          isA<ItemLockedException>().having(
            (error) => error.passwordHint,
            'password hint',
            'Favorite first pet',
          ),
        ),
      );
      await expectLater(
        repository.revealSecretPayloadJit(
          item.itemUuid,
          itemPassword: 'IncorrectItemPassword',
        ),
        throwsA(isA<ItemLockedException>()),
      );

      final opened = await repository.revealSecretPayloadJit(
        item.itemUuid,
        itemPassword: 'DistinctItemPassword1',
      );
      expect(opened.secretText, 'extra private payload');
      expect(opened.hasExtraLock, isTrue);
      final shared = await repository.exportSingleItemSxsi(
        itemUuid: item.itemUuid,
        filePassword: 'ShareFilePassword1',
        itemPassword: 'DistinctItemPassword1',
      );
      expect(shared.startsWith('SXSI1:'), isTrue);
      await expectLater(
        repository.exportSingleItemSxsi(
          itemUuid: item.itemUuid,
          filePassword: 'ShareFilePassword1',
          itemPassword: 'WrongItemPassword',
        ),
        throwsA(isA<ItemLockedException>()),
      );

      await repository.setupDualSlotVault(
        mainPassword: 'VaultPasswordChanged#2026',
        secondaryPassword: 'SecondaryPasswordChanged',
      );
      await expectLater(
        repository.revealSecretPayloadJit(
          item.itemUuid,
          itemPassword: 'DistinctItemPassword1',
        ),
        throwsA(isA<VaultItemPasswordException>()),
      );
      final afterVaultPasswordChange = await repository.revealSecretPayloadJit(
        item.itemUuid,
        overridePassword: 'VaultPasswordOriginal#2026',
        itemPassword: 'DistinctItemPassword1',
      );
      expect(afterVaultPasswordChange.secretText, 'extra private payload');
    });

    test('Extra Lock can be added, changed, and removed without data loss',
        () async {
      await repository.unlockVault('SuperSecret#2026');
      final item = await repository.saveTopic(
        topic: 'Manage lock',
        secretText: 'keep this secret',
      );

      await repository.setItemExtraLock(
        itemUuid: item.itemUuid,
        newItemPassword: 'FirstItemPassword1',
        passwordHint: 'First hint',
      );
      await expectLater(
        repository.revealSecretPayloadJit(item.itemUuid),
        throwsA(isA<ItemLockedException>()),
      );
      await repository.setItemExtraLock(
        itemUuid: item.itemUuid,
        newItemPassword: 'SecondItemPassword2',
        passwordHint: 'Updated hint',
        currentItemPassword: 'FirstItemPassword1',
      );
      final changed = await repository.revealSecretPayloadJit(
        item.itemUuid,
        itemPassword: 'SecondItemPassword2',
      );
      expect(changed.secretText, 'keep this secret');
      expect(changed.passwordHint, 'Updated hint');

      await repository.removeItemExtraLock(
        itemUuid: item.itemUuid,
        itemPassword: 'SecondItemPassword2',
      );
      final unlocked = await repository.revealSecretPayloadJit(item.itemUuid);
      expect(unlocked.secretText, 'keep this secret');
      expect(unlocked.hasExtraLock, isFalse);
    });

    test('.sxs backup restore preserves Extra Lock ciphertext and metadata',
        () async {
      await repository.setupDualSlotVault(
        mainPassword: 'BackupVaultPassword#2026',
        secondaryPassword: 'BackupSecondaryPassword#2026',
      );
      final item = await repository.saveTopic(
        topic: 'Backed up locked item',
        secretText: 'backup secret',
        hasExtraLock: true,
        itemPassword: 'BackupItemPassword1',
        passwordHint: 'Backup hint',
      );
      final backup = await repository.exportSxsBackup(
        verifyMasterPassword: 'BackupVaultPassword#2026',
        backupEncryptionPassword: 'BackupFilePassword1',
      );
      await repository.saveTopic(topic: 'After backup', secretText: 'discard');

      await repository.restoreSxsBackup(
        backupBytes: backup,
        backupFilePassword: 'BackupFilePassword1',
      );
      final restored = await repository.fetchVaultSummaries();
      expect(
          restored.any((summary) => summary.topic == 'After backup'), isFalse);
      final restoredItem =
          restored.singleWhere((summary) => summary.itemUuid == item.itemUuid);
      expect(restoredItem.hasExtraLock, isTrue);
      expect(restoredItem.passwordHint, 'Backup hint');
      final decoded = await repository.revealSecretPayloadJit(
        item.itemUuid,
        itemPassword: 'BackupItemPassword1',
      );
      expect(decoded.secretText, 'backup secret');
    });

    test('.sxsi single-item share verifies SXSI magic header and File Password',
        () async {
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

    test('.sxs full backup container begins with SXSV magic header bytes',
        () async {
      await repository.unlockVault('SuperSecret#2026');
      final sxsBytes = await repository.exportSxsBackup(
        verifyMasterPassword: 'SuperSecret#2026',
        backupEncryptionPassword: 'OfflineBackupPassword#1',
      );

      // Verify "SXSV" (0x53, 0x58, 0x53, 0x56) magic header
      expect(sxsBytes.sublist(0, 4), equals([0x53, 0x58, 0x53, 0x56]));
    });

    testWidgets('View shows progress while the secret is being unlocked',
        (tester) async {
      final item = VaultTopicSummary(
        itemUuid: 'delayed-view',
        topic: 'Delayed item',
        updatedAt: DateTime(2026),
      );
      final service = _DelayedViewService(item);
      final viewModel = VaultViewModel(
        vaultRepository: VaultRepository(
          rustFfiService: service,
          osHardeningService: OsHardeningService(),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: VaultDashboardView(
            viewModel: viewModel,
            onLockRequested: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('View'));
      await tester.pump();
      expect(find.text('Opening...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      service.revealCompleter.complete(
        DecodedTopicSecret(
          itemUuid: item.itemUuid,
          topic: item.topic,
          secretText: 'revealed secret',
        ),
      );
      await tester.pump();
      expect(find.text('revealed secret'), findsOneWidget);
      expect(find.text('Opening...'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      viewModel.dispose();
    });

    testWidgets(
        'Unlocked VaultDashboardView renders identical UI without Main/Fake badges',
        (tester) async {
      await repository.unlockVault('Decoy1234');
      final viewModel = VaultViewModel(vaultRepository: repository);

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

      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);
      expect(find.text('View'), findsWidgets);
      expect(find.text('Share'), findsWidgets);
      expect(find.text('Email'), findsNothing);
      expect(find.text('Bank'), findsNothing);
      expect(find.text('Crypto'), findsNothing);
      expect(find.textContaining('FAKE'), findsNothing);
      expect(find.textContaining('DECOY'), findsNothing);
    });

    testWidgets('New Topic offers the optional Extra Lock password fields',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await repository.unlockVault('SuperSecret#2026');
      final viewModel = VaultViewModel(vaultRepository: repository);
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
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 10),
      );

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 10),
      );
      expect(find.text('🔒 Extra Lock (Separate Password)'), findsOneWidget);
      await tester.tap(find.text('🔒 Extra Lock (Separate Password)'));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 10),
      );

      expect(find.text('Item Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.text('Password Hint'), findsOneWidget);
    });

    testWidgets('Lock screen does not expose Quick Demo credentials',
        (tester) async {
      final authViewModel = AuthViewModel(vaultRepository: repository);
      await tester.pumpWidget(
        MaterialApp(
          home: LockScreenView(
            viewModel: authViewModel,
            onVaultUnlocked: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quick Demo:'), findsNothing);
      expect(
          find.textContaining('Main Vault (SuperSecret#2026)'), findsNothing);
      authViewModel.dispose();
    });
  });
}

class _DelayedViewService extends RustVaultFfiService {
  _DelayedViewService(this.summary);

  final VaultTopicSummary summary;
  final Completer<DecodedTopicSecret> revealCompleter =
      Completer<DecodedTopicSecret>();

  @override
  Future<List<VaultTopicSummary>> listSummaries() async => [summary];

  @override
  Future<DecodedTopicSecret> decryptPayloadJit(
    String itemUuid, {
    String? overridePassword,
    String? itemPassword,
  }) {
    return revealCompleter.future;
  }
}
