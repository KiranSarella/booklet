import 'package:flutter/foundation.dart';
import 'package:booklet/application/page_settings_controller.dart';

import 'editor_controller.dart';

enum AppScreen { startup, editor }

class App extends ChangeNotifier {
  App(this.editorTheme) : editorController = EditorController(editorTheme);

  final PageSettingsController editorTheme;
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
    super.dispose();
  }
}
