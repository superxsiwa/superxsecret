import 'dart:io';
import 'dart:typed_data';
import 'picked_file_data.dart';

void downloadFile({
  required String fileName,
  required List<int> bytes,
  String mimeType = 'application/octet-stream',
}) {
  try {
    final dir = Directory.systemTemp;
    final file = File('${dir.path}/$fileName');
    file.writeAsBytesSync(bytes);
  } catch (_) {}
}

Future<String?> pickFileText({
  List<String> allowedExtensions = const ['sxsi', 'sxs', 'txt'],
}) async {
  return null;
}

Future<Uint8List?> pickFileBytes({
  List<String> allowedExtensions = const ['sxsi', 'sxs', 'bin'],
}) async {
  return null;
}

Future<PickedFileData?> pickAnyFile({
  List<String>? allowedExtensions,
  String? mimeTypeFilter,
}) async {
  return null;
}

