import 'package:flutter/foundation.dart';
import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';

import 'editor_controller.dart';

enum AppScreen { startup, editor }

class App extends ChangeNotifier {
  App(this.editorTheme, this.documentSettingsController)
    : editorController = EditorController(
        editorTheme,
        documentSettingsController,
      );

  final PageSettingsController editorTheme;
  final DocumentSettingsController documentSettingsController;
  final EditorController editorController;
  AppScreen _screen = AppScreen.startup;

  AppScreen get screen => _screen;

  void createBooklet() {
    editorController.createBooklet();
    _showEditor();
  }

  Future<bool> openBooklet() async {
    final opened = await editorController.openBooklet();
    if (opened) {
      _showEditor();
    }
    return opened;
  }

  Future<bool> openBookletAtPath(String path) async {
    final opened = await editorController.openBookletAtPath(path);
    if (opened) {
      _showEditor();
    }
    return opened;
  }

  void _showEditor() {
    if (_screen == AppScreen.editor) {
      return;
    }

    _screen = AppScreen.editor;
    notifyListeners();
  }

  @override
  void dispose() {
    editorController.dispose();
    editorTheme.dispose();
    documentSettingsController.dispose();
    super.dispose();
  }
}
