import 'dart:typed_data';

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
