// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

void downloadFile({
  required String fileName,
  required List<int> bytes,
  String mimeType = 'application/octet-stream',
}) {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..target = 'blank'
    ..download = fileName;
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

Future<String?> pickFileText({
  List<String> allowedExtensions = const ['sxsi', 'sxs', 'txt'],
}) async {
  final input = html.FileUploadInputElement();
  input.accept = allowedExtensions.map((e) => '.$e').join(',');
  input.click();

  await input.onChange.first;
  if (input.files == null || input.files!.isEmpty) return null;

  final file = input.files!.first;
  final reader = html.FileReader();
  reader.readAsText(file);
  await reader.onLoad.first;
  return reader.result as String?;
}

Future<Uint8List?> pickFileBytes({
  List<String> allowedExtensions = const ['sxsi', 'sxs', 'bin'],
}) async {
  final input = html.FileUploadInputElement();
  input.accept = allowedExtensions.map((e) => '.$e').join(',');
  input.click();

  await input.onChange.first;
  if (input.files == null || input.files!.isEmpty) return null;

  final file = input.files!.first;
  final reader = html.FileReader();
  reader.readAsArrayBuffer(file);
  await reader.onLoad.first;
  final result = reader.result;
  if (result is Uint8List) return result;
  if (result is List<int>) return Uint8List.fromList(result);
  return null;
}

class PickedFileData {
  const PickedFileData({
    required this.name,
    required this.size,
    required this.bytes,
    this.mimeType,
  });

  final String name;
  final int size;
  final Uint8List bytes;
  final String? mimeType;
}

Future<PickedFileData?> pickAnyFile({
  List<String>? allowedExtensions,
  String? mimeTypeFilter,
}) async {
  final input = html.FileUploadInputElement();
  if (mimeTypeFilter != null && mimeTypeFilter.isNotEmpty) {
    input.accept = mimeTypeFilter;
  } else if (allowedExtensions != null && allowedExtensions.isNotEmpty) {
    input.accept = allowedExtensions.map((e) => '.$e').join(',');
  }
  input.click();

  await input.onChange.first;
  if (input.files == null || input.files!.isEmpty) return null;

  final file = input.files!.first;
  final reader = html.FileReader();
  reader.readAsArrayBuffer(file);
  await reader.onLoad.first;
  final result = reader.result;
  final Uint8List bytes;
  if (result is Uint8List) {
    bytes = result;
  } else if (result is List<int>) {
    bytes = Uint8List.fromList(result);
  } else {
    return null;
  }

  return PickedFileData(
    name: file.name,
    size: file.size,
    bytes: bytes,
    mimeType: file.type.isNotEmpty ? file.type : null,
  );
}
