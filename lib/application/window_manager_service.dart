import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';

/// Thin wrapper around `desktop_multi_window` so the rest of the app never
/// imports the plugin directly — keeps a future swap to a native window
/// manager localized to this file.
class WindowManagerService {
  static const _documentPathKey = 'documentPath';

  Future<void> openDocumentInNewWindow(String? documentPath) async {
    final arguments = jsonEncode({_documentPathKey: documentPath});
    final controller = await WindowController.create(
      WindowConfiguration(hiddenAtLaunch: true, arguments: arguments),
    );
    await controller.show();
  }

  /// Reads the document path (if any) a new window was launched with.
  static String? parseDocumentPath(String arguments) {
    if (arguments.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(arguments);
      if (decoded is Map && decoded[_documentPathKey] is String) {
        return decoded[_documentPathKey] as String;
      }
    } on FormatException {
      // Not JSON we recognize; treat as a fresh window with no document.
    }
    return null;
  }
}
