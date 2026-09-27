import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';

class DocumentSettingsVM {
  DocumentSettingsVM({
    required this.settingsController,
    required this.editorTheme,
  });

  final DocumentSettingsController settingsController;
  final PageSettingsController editorTheme;

  DocumentEditMode get editMode => settingsController.editMode;
  EditorAppearanceMode get appearanceMode => editorTheme.appearanceMode;

  void updateEditMode(DocumentEditMode mode) =>
      settingsController.updateEditMode(mode);

  void updateAppearanceMode(EditorAppearanceMode mode) =>
      editorTheme.updateAppearanceMode(mode);
}
