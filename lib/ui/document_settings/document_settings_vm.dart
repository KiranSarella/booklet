import 'package:booklet/application/appearance_mode.dart';
import 'package:booklet/application/document_settings_controller.dart';

class DocumentSettingsVM {
  DocumentSettingsVM({required this.settingsController});

  final DocumentSettingsController settingsController;

  DocumentEditMode get editMode => settingsController.editMode;
  EditorAppearanceMode get appearanceMode => settingsController.appearanceMode;

  void updateEditMode(DocumentEditMode mode) =>
      settingsController.updateEditMode(mode);

  void updateAppearanceMode(EditorAppearanceMode mode) =>
      settingsController.updateAppearanceMode(mode);
}
