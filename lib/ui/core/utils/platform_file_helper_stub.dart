import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/privacy_curtain_wrapper.dart';
import 'picked_file_data.dart';

void downloadFile({
  required String fileName,
  required List<int> bytes,
  String mimeType = 'application/octet-stream',
}) async {
  PrivacyCurtainWrapper.beginIntentInteraction();
  File? tempFile;
  try {
    Directory? targetDir;
    try {
      targetDir = await getDownloadsDirectory();
    } catch (_) {}
    final isTemp = targetDir == null;
    targetDir ??= await getTemporaryDirectory();

    final file = File('${targetDir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    if (isTemp) {
      tempFile = file;
    }

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, name: fileName, mimeType: mimeType)],
        text: 'SuperXSecret: $fileName',
      ),
    );
  } catch (_) {
    try {
      final file = File('${Directory.systemTemp.path}/$fileName');
      file.writeAsBytesSync(bytes);
    } catch (_) {}
  } finally {
    Future<void>.delayed(const Duration(milliseconds: 1000), () {
      PrivacyCurtainWrapper.endIntentInteraction();
      try {
        if (tempFile != null && tempFile.existsSync()) {
          tempFile.deleteSync();
        }
      } catch (_) {}
    });
  }
}

Future<String?> pickFileText({
  List<String> allowedExtensions = const ['sxsi', 'sxs', 'txt'],
}) async {
  PrivacyCurtainWrapper.beginIntentInteraction();
  try {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );
    if (files.isEmpty) return null;
    final picked = files.first;
    if (picked.path != null) {
      return await File(picked.path!).readAsString();
    }
  } catch (_) {
  } finally {
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      PrivacyCurtainWrapper.endIntentInteraction();
    });
  }
  return null;
}

Future<Uint8List?> pickFileBytes({
  List<String> allowedExtensions = const ['sxsi', 'sxs', 'bin'],
}) async {
  PrivacyCurtainWrapper.beginIntentInteraction();
  try {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );
    if (files.isEmpty) return null;
    final picked = files.first;
    if (picked.path != null) {
      return await File(picked.path!).readAsBytes();
    }
  } catch (_) {
  } finally {
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      PrivacyCurtainWrapper.endIntentInteraction();
    });
  }
  return null;
}

Future<PickedFileData?> pickAnyFile({
  List<String>? allowedExtensions,
  String? mimeTypeFilter,
}) async {
  PrivacyCurtainWrapper.beginIntentInteraction();
  try {
    var pickerType = FileType.any;
    if (allowedExtensions != null && allowedExtensions.isNotEmpty) {
      pickerType = FileType.custom;
    } else if (mimeTypeFilter != null) {
      if (mimeTypeFilter.startsWith('image/')) {
        pickerType = FileType.image;
      } else if (mimeTypeFilter.startsWith('video/')) {
        pickerType = FileType.video;
      } else if (mimeTypeFilter.startsWith('audio/')) {
        pickerType = FileType.audio;
      }
    }

    final files = await FilePicker.pickFiles(
      type: pickerType,
      allowedExtensions: pickerType == FileType.custom ? allowedExtensions : null,
    );
    if (files.isEmpty) return null;
    final file = files.first;

    if (file.path != null) {
      final localFile = File(file.path!);
      final fileBytes = await localFile.readAsBytes();
      final size = await localFile.length();
      return PickedFileData(
        name: file.name,
        size: size,
        bytes: fileBytes,
        mimeType: mimeTypeFilter,
      );
    }
  } catch (_) {
  } finally {
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      PrivacyCurtainWrapper.endIntentInteraction();
    });
  }
  return null;
}
