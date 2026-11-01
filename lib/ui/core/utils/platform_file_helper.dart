import 'dart:typed_data';

import 'platform_file_helper_stub.dart'
    if (dart.library.html) 'platform_file_helper_web.dart' as impl;

abstract final class PlatformFileHelper {
  static void downloadFile({
    required String fileName,
    required List<int> bytes,
    String mimeType = 'application/octet-stream',
  }) {
    impl.downloadFile(fileName: fileName, bytes: bytes, mimeType: mimeType);
  }

  static Future<String?> pickFileText({
    List<String> allowedExtensions = const ['sxsi', 'sxs', 'txt'],
  }) {
    return impl.pickFileText(allowedExtensions: allowedExtensions);
  }

  static Future<Uint8List?> pickFileBytes({
    List<String> allowedExtensions = const ['sxsi', 'sxs', 'bin'],
  }) {
    return impl.pickFileBytes(allowedExtensions: allowedExtensions);
  }
}

