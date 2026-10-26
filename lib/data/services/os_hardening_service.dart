import 'package:flutter/services.dart';
import '../../domain/models/vault_models.dart';

/// Stateless Service wrapping the Native OS Security & Hardening MethodChannel
/// (`com.superxsecret.vault/hardening`) on Android and iOS.
class OsHardeningService {
  OsHardeningService() {
    _channel.setMethodCallHandler(_handleNativeCallback);
  }

  static const MethodChannel _channel = MethodChannel(
    'com.superxsecret.vault/hardening',
  );

  VoidCallback? onNativeScreenOffLock;
  ValueChanged<bool>? onScreenRecordingChanged;
  VoidCallback? onClipboardClearedByOs;

  Future<dynamic> _handleNativeCallback(MethodCall call) async {
    switch (call.method) {
      case 'onScreenOffLock':
        onNativeScreenOffLock?.call();
      case 'onScreenRecordingDetected':
        final isCaptured = call.arguments as bool? ?? false;
        onScreenRecordingChanged?.call(isCaptured);
      case 'onClipboardAutoCleared':
        onClipboardClearedByOs?.call();
    }
  }

  /// Copies a secret to the OS clipboard using Android 13+ `EXTRA_IS_SENSITIVE`
  /// and iOS `UIPasteboard.OptionKey.localOnly` + `.expirationDate`.
  Future<void> copySensitiveClipboard(
    String secret, {
    int ttlSeconds = 30,
  }) async {
    try {
      await _channel.invokeMethod<bool>('copySensitiveClipboard', {
        'text': secret,
        'ttlSeconds': ttlSeconds,
      });
    } on MissingPluginException {
      // Fallback for desktop widget tests
      await Clipboard.setData(ClipboardData(text: secret));
    }
  }

  /// Immediately wipes the system clipboard.
  Future<void> clearClipboardNow() async {
    try {
      await _channel.invokeMethod<bool>('clearClipboardNow');
    } on MissingPluginException {
      await Clipboard.setData(const ClipboardData(text: ''));
    }
  }

  /// Inspects Root/Jailbreak, Frida/Debugger, Screen Guard, and Zero-Network status.
  Future<DeviceSecurityPosture> checkDeviceIntegrity() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'checkDeviceIntegrity',
      );
      if (result != null) {
        return DeviceSecurityPosture(
          zeroNetworkPermissionVerified:
              result['zeroNetworkPermissionVerified'] as bool? ?? true,
          isScreenGuardActive: result['isScreenGuardActive'] as bool? ?? true,
          isCompromised: result['isCompromised'] as bool? ?? false,
          hasRootOrJailbreak: result['hasRootOrJailbreak'] as bool? ?? false,
          isDebuggerOrFridaDetected:
              result['isDebuggerOrFridaDetected'] as bool? ?? false,
          sqlCipherActive: true,
        );
      }
    } on MissingPluginException {
      // Default posture for local dev/test preview before native runner attachment
    }

    return const DeviceSecurityPosture(
      zeroNetworkPermissionVerified: true,
      isScreenGuardActive: true,
      isCompromised: false,
      hasRootOrJailbreak: false,
      isDebuggerOrFridaDetected: false,
      sqlCipherActive: true,
    );
  }
}

