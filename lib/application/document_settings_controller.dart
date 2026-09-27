
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DocumentEditMode { edit, readOnly }

// Document-only appearance: Gray has no equivalent in page_settings, where it
// is simply treated as light when that feature's appearance mode is 'auto'.
enum DocumentAppearanceMode { light, gray, dark, auto }

class DocumentSettingsController extends ChangeNotifier {
  static const _editModeKey = 'document.editMode';
  static const _appearanceModeKey = 'document.appearanceMode';

  DocumentEditMode _editMode = DocumentEditMode.edit;
  DocumentAppearanceMode _appearanceMode = DocumentAppearanceMode.auto;
  Brightness _systemBrightness = Brightness.light;

  DocumentEditMode get editMode => _editMode;
  bool get isReadOnly => _editMode == DocumentEditMode.readOnly;

  // Primary appearance: scopes the whole application (navigation, menus, etc.), not the page view.
  DocumentAppearanceMode get appearanceMode => _appearanceMode;
  bool get isGray => _appearanceMode == DocumentAppearanceMode.gray;
  ThemeMode get themeMode => switch (_appearanceMode) {
    DocumentAppearanceMode.light => ThemeMode.light,
    DocumentAppearanceMode.gray => ThemeMode.light,
    DocumentAppearanceMode.dark => ThemeMode.dark,
    DocumentAppearanceMode.auto => ThemeMode.system,
  };
  Brightness get effectiveBrightness =>
      _appearanceMode == DocumentAppearanceMode.auto
      ? _systemBrightness
      : _appearanceMode == DocumentAppearanceMode.dark
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
    _appearanceMode = DocumentAppearanceMode.values.firstWhere(
      (mode) => mode.name == savedAppearance,
      orElse: () => DocumentAppearanceMode.auto,
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

  void updateAppearanceMode(DocumentAppearanceMode mode) {
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
    if (_appearanceMode == DocumentAppearanceMode.auto) {
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_editModeKey, _editMode.name);
    await preferences.setString(_appearanceModeKey, _appearanceMode.name);
  }
}
