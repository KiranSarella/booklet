import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/editor_controller.dart';

class DocumentSettingsVM {
  DocumentSettingsVM({
    required this.settingsController,
    required this.editorController,
  });

  final DocumentSettingsController settingsController;
  final EditorController editorController;

  DocumentEditMode get editMode => settingsController.editMode;
  DocumentAppearanceMode get appearanceMode =>
      settingsController.appearanceMode;

  void updateEditMode(DocumentEditMode mode) =>
      settingsController.updateEditMode(mode);

  void updateAppearanceMode(DocumentAppearanceMode mode) =>
      settingsController.updateAppearanceMode(mode);

  Future<void> importMarkdown() => editorController.importMarkdown();
}
