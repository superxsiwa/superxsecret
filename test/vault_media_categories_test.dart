import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:superxsecret/data/repositories/vault_repository.dart';
import 'package:superxsecret/data/services/os_hardening_service.dart';
import 'package:superxsecret/data/services/rust_vault_ffi_service.dart';
import 'package:superxsecret/domain/models/vault_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RustVaultFfiService ffiService;
  late OsHardeningService osHardeningService;
  late VaultRepository repository;

  setUp(() async {
    ffiService = RustVaultFfiService();
    osHardeningService = OsHardeningService();
    repository = VaultRepository(
      rustFfiService: ffiService,
      osHardeningService: osHardeningService,
    );
    await repository.unlockVault('SuperSecret#2026');
  });

  group('SuperXSecret 5-Category Media & File Encryption Tests', () {
    test('Image Encryption: Encrypts and decrypts raw image bytes with metadata',
        () async {
      final fakePngBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG magic
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
      ]);

      final created = await repository.saveTopic(
        topic: 'ID Card Scan',
        secretText: 'Front side of national ID',
        cipherType: VaultCipherType.aes256Gcm,
        category: VaultItemCategory.image,
        fileName: 'id_card.png',
        fileSizeBytes: fakePngBytes.length,
        mimeType: 'image/png',
        rawBytes: fakePngBytes,
      );

      expect(created.category, equals(VaultItemCategory.image));
      expect(created.fileName, equals('id_card.png'));
      expect(created.fileSizeBytes, equals(fakePngBytes.length));

      final revealed =
          await repository.revealSecretPayloadJit(created.itemUuid);
      expect(revealed.category, equals(VaultItemCategory.image));
      expect(revealed.topic, equals('ID Card Scan'));
      expect(revealed.secretText, equals('Front side of national ID'));
      expect(revealed.fileName, equals('id_card.png'));
      expect(revealed.fileSizeBytes, equals(fakePngBytes.length));
      expect(revealed.rawBytes, isNotNull);
      expect(revealed.rawBytes, equals(fakePngBytes));
    });

    test('Audio Encryption: Encrypts and decrypts audio bytes with ChaCha20',
        () async {
      final fakeMp3Bytes = Uint8List.fromList(
        List.generate(256, (i) => (i * 7) % 256),
      );

      final created = await repository.saveTopic(
        topic: 'Meeting Recording',
        secretText: 'Important audio evidence',
        cipherType: VaultCipherType.chacha20Poly1305,
        category: VaultItemCategory.audio,
        fileName: 'meeting_secret.mp3',
        fileSizeBytes: fakeMp3Bytes.length,
        mimeType: 'audio/mpeg',
        rawBytes: fakeMp3Bytes,
      );

      expect(created.category, equals(VaultItemCategory.audio));

      final revealed =
          await repository.revealSecretPayloadJit(created.itemUuid);
      expect(revealed.category, equals(VaultItemCategory.audio));
      expect(revealed.cipherType, equals(VaultCipherType.chacha20Poly1305));
      expect(revealed.rawBytes, equals(fakeMp3Bytes));
    });

    test('Video Encryption: Encrypts and decrypts video with XChaCha20',
        () async {
      final fakeMp4Bytes = Uint8List.fromList(
        List.generate(512, (i) => (i * 13) % 256),
      );

      final created = await repository.saveTopic(
        topic: 'Vault Security Cam',
        secretText: 'Encrypted clip',
        cipherType: VaultCipherType.xchacha20Poly1305,
        category: VaultItemCategory.video,
        fileName: 'vault_cam.mp4',
        fileSizeBytes: fakeMp4Bytes.length,
        mimeType: 'video/mp4',
        rawBytes: fakeMp4Bytes,
      );

      final revealed =
          await repository.revealSecretPayloadJit(created.itemUuid);
      expect(revealed.category, equals(VaultItemCategory.video));
      expect(revealed.cipherType, equals(VaultCipherType.xchacha20Poly1305));
      expect(revealed.rawBytes, equals(fakeMp4Bytes));
    });

    test(
        'General File Encryption: Encrypts document file with Dual-Cipher and Extra Lock',
        () async {
      final fakePdfBytes = Uint8List.fromList(
        utf8.encode('%PDF-1.7 Confidential Contract Agreement Document'),
      );

      final created = await repository.saveTopic(
        topic: 'Signed NDA 2026',
        secretText: 'Project SuperX contract',
        cipherType: VaultCipherType.dualCipher,
        category: VaultItemCategory.file,
        fileName: 'nda_signed.pdf',
        fileSizeBytes: fakePdfBytes.length,
        mimeType: 'application/pdf',
        rawBytes: fakePdfBytes,
        hasExtraLock: true,
        itemPassword: 'ItemPassword#999',
        passwordHint: 'Lawyer date',
      );

      expect(created.category, equals(VaultItemCategory.file));
      expect(created.hasExtraLock, isTrue);

      expect(
        () => repository.revealSecretPayloadJit(created.itemUuid),
        throwsA(isA<ItemLockedException>()),
      );

      final revealed = await repository.revealSecretPayloadJit(
        created.itemUuid,
        itemPassword: 'ItemPassword#999',
      );
      expect(revealed.category, equals(VaultItemCategory.file));
      expect(revealed.cipherType, equals(VaultCipherType.dualCipher));
      expect(revealed.rawBytes, equals(fakePdfBytes));
    });

    test('.sxsi export and import preserves category, filename, and binary bytes',
        () async {
      final fakeImage = Uint8List.fromList([1, 2, 3, 4, 5, 42, 99]);
      final created = await repository.saveTopic(
        topic: 'Shared Graphic',
        secretText: 'Brand Asset',
        cipherType: VaultCipherType.aes256Gcm,
        category: VaultItemCategory.image,
        fileName: 'logo.png',
        fileSizeBytes: fakeImage.length,
        mimeType: 'image/png',
        rawBytes: fakeImage,
      );

      final sxsiPacket = await repository.exportSingleItemSxsi(
        itemUuid: created.itemUuid,
        filePassword: 'ShareFilePassword#1',
      );

      final imported = await repository.importSingleItemSxsi(
        sxsiPacket: sxsiPacket,
        filePassword: 'ShareFilePassword#1',
      );

      expect(imported.category, equals(VaultItemCategory.image));
      expect(imported.fileName, equals('logo.png'));
      expect(imported.fileSizeBytes, equals(fakeImage.length));

      final revealed =
          await repository.revealSecretPayloadJit(imported.itemUuid);
      expect(revealed.category, equals(VaultItemCategory.image));
      expect(revealed.fileName, equals('logo.png'));
      expect(revealed.rawBytes, equals(fakeImage));
    });

    test('.sxs full backup preserves all categories and metadata',
        () async {
      await repository.saveTopic(
        topic: 'Audio Note',
        secretText: 'Voice note',
        category: VaultItemCategory.audio,
        fileName: 'voice.m4a',
        fileSizeBytes: 1024,
      );
      await repository.saveTopic(
        topic: 'Passport Scan',
        secretText: 'Photo',
        category: VaultItemCategory.image,
        fileName: 'passport.jpg',
        fileSizeBytes: 2048,
      );

      final backupBytes = await repository.exportSxsBackup(
        verifyMasterPassword: 'SuperSecret#2026',
        backupEncryptionPassword: 'BackupPassword#2026',
      );

      await repository.restoreSxsBackup(
        backupBytes: backupBytes,
        backupFilePassword: 'BackupPassword#2026',
      );

      final restored = await repository.fetchVaultSummaries();
      final audioItem =
          restored.firstWhere((i) => i.category == VaultItemCategory.audio);
      final imageItem =
          restored.firstWhere((i) => i.category == VaultItemCategory.image);

      expect(audioItem.fileName, equals('voice.m4a'));
      expect(imageItem.fileName, equals('passport.jpg'));
    });
  });
}
