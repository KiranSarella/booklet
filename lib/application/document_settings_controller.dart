
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DocumentEditMode { edit, readOnly }

class DocumentSettingsController extends ChangeNotifier {
  static const _editModeKey = 'document.editMode';

  DocumentEditMode _editMode = DocumentEditMode.edit;

  DocumentEditMode get editMode => _editMode;
  bool get isReadOnly => _editMode == DocumentEditMode.readOnly;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final savedMode = preferences.getString(_editModeKey);
    _editMode = DocumentEditMode.values.firstWhere(
      (mode) => mode.name == savedMode,
      orElse: () => DocumentEditMode.edit,
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

  Future<void> _persist() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_editModeKey, _editMode.name);
  }
}