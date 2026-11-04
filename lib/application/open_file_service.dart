import 'package:flutter/services.dart';

/// Receives `.booklet` paths the OS asks the app to open (Finder double-click).
class OpenFileService {
  static const _channel = MethodChannel('booklet/open_file');

  Future<String?> pickAndroidBooklet() =>
      _channel.invokeMethod<String>('pickBooklet');

  Future<void> listen(
    Future<void> Function(String path) onOpen, {
    VoidCallback? onError,
  }) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openError') {
        onError?.call();
      } else if (call.method == 'openFile') {
        await onOpen(call.arguments as String);
      }
    });

    // Covers a file that launched the app before this handler existed.
    try {
      final initialPath = await _channel.invokeMethod<String>(
        'takeInitialFile',
      );
      if (initialPath != null) {
        await onOpen(initialPath);
      }
    } on PlatformException {
      onError?.call();
    } on MissingPluginException {
      // Platforms/windows without the native side have nothing to open.
    }
  }
}
