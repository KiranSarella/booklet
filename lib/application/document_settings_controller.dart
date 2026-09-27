
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:booklet/application/appearance_mode.dart';

enum DocumentEditMode { edit, readOnly }

class DocumentSettingsController extends ChangeNotifier {
  static const _editModeKey = 'document.editMode';
  static const _appearanceModeKey = 'document.appearanceMode';

  DocumentEditMode _editMode = DocumentEditMode.edit;
  EditorAppearanceMode _appearanceMode = EditorAppearanceMode.auto;
  Brightness _systemBrightness = Brightness.light;

  DocumentEditMode get editMode => _editMode;
  bool get isReadOnly => _editMode == DocumentEditMode.readOnly;

  // Primary appearance: scopes the whole application (navigation, menus, etc.), not the page view.
  EditorAppearanceMode get appearanceMode => _appearanceMode;
  ThemeMode get themeMode => switch (_appearanceMode) {
    EditorAppearanceMode.light => ThemeMode.light,
    EditorAppearanceMode.dark => ThemeMode.dark,
    EditorAppearanceMode.auto => ThemeMode.system,
  };
  Brightness get effectiveBrightness =>
      _appearanceMode == EditorAppearanceMode.auto
      ? _systemBrightness
      : _appearanceMode == EditorAppearanceMode.dark
      ? Brightness.dark
      : Brightness.light;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final savedMode = preferences.getString(_editModeKey);
    _editMode = DocumentEditMode.values.firstWhere(
      (mode) => mode.name == savedMode,
      orElse: () => DocumentEditMode.edit,
    );
    final savedAppearance = preferences.getString(_appearanceModeKey);
    _appearanceMode = EditorAppearanceMode.values.firstWhere(
      (mode) => mode.name == savedAppearance,
      orElse: () => EditorAppearanceMode.auto,
    );
    notifyListeners();
  }

  void updateEditMode(DocumentEditMode mode) {
    if (_editMode == mode) {
      return;
    }
    _editMode = mode;
    notifyListeners();
    _persist();
  }

  void updateAppearanceMode(EditorAppearanceMode mode) {
    if (_appearanceMode == mode) {
      return;
    }
    _appearanceMode = mode;
    notifyListeners();
    _persist();
  }

  void updateSystemBrightness(Brightness brightness) {
    if (_systemBrightness == brightness) {
      return;
    }
    _systemBrightness = brightness;
    if (_appearanceMode == EditorAppearanceMode.auto) {
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_editModeKey, _editMode.name);
    await preferences.setString(_appearanceModeKey, _appearanceMode.name);
  }
}
