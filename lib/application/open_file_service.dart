import 'package:flutter/services.dart';

/// Receives `.booklet` paths the OS asks the app to open (Finder double-click).
class OpenFileService {
  static const _channel = MethodChannel('booklet/open_file');

  Future<void> listen(Future<void> Function(String path) onOpen) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openFile') {
        await onOpen(call.arguments as String);
      }
    });

    // Covers a file that launched the app before this handler existed.
    try {
      final initialPath = await _channel.invokeMethod<String>('takeInitialFile');
      if (initialPath != null) {
        await onOpen(initialPath);
      }
    } on MissingPluginException {
      // Platforms/windows without the native side have nothing to open.
    }
  }
}
