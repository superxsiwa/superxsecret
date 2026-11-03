import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'picked_file_data.dart';

void downloadFile({
  required String fileName,
  required List<int> bytes,
  String mimeType = 'application/octet-stream',
}) async {
  try {
    Directory? targetDir;
    try {
      targetDir = await getDownloadsDirectory();
    } catch (_) {}
    targetDir ??= await getTemporaryDirectory();

    final file = File('${targetDir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

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
  }
}

Future<String?> pickFileText({
  List<String> allowedExtensions = const ['sxsi', 'sxs', 'txt'],
}) async {
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
  } catch (_) {}
  return null;
}

Future<Uint8List?> pickFileBytes({
  List<String> allowedExtensions = const ['sxsi', 'sxs', 'bin'],
}) async {
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
  } catch (_) {}
  return null;
}

Future<PickedFileData?> pickAnyFile({
  List<String>? allowedExtensions,
  String? mimeTypeFilter,
}) async {
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
  } catch (_) {}
  return null;
}
