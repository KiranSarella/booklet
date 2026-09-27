import 'package:flutter/material.dart';
import 'package:booklet/application/appearance_mode.dart';
import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/ui/document_settings/document_settings_vm.dart';

class DocumentSettingsDialog extends StatelessWidget {
  const DocumentSettingsDialog({super.key, required this.viewModel});

  final DocumentSettingsVM viewModel;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Document settings'),
      content: SizedBox(
        width: 360,
        child: AnimatedBuilder(
          animation: viewModel.settingsController,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mode', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<DocumentEditMode>(
                  segments: const [
                    ButtonSegment(
                      value: DocumentEditMode.edit,
                      label: Text('Edit'),
                      icon: Icon(Icons.edit_outlined),
                    ),
                    ButtonSegment(
                      value: DocumentEditMode.readOnly,
                      label: Text('Read only'),
                      icon: Icon(Icons.lock_outline),
                    ),
                  ],
                  selected: {viewModel.editMode},
                  onSelectionChanged: (selection) =>
                      viewModel.updateEditMode(selection.first),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Appearance',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                'Applies to the whole app (navigation, menus). Not the page view.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<EditorAppearanceMode>(
                  segments: const [
                    ButtonSegment(
                      value: EditorAppearanceMode.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode_outlined),
                    ),
                    ButtonSegment(
                      value: EditorAppearanceMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode_outlined),
                    ),
                    ButtonSegment(
                      value: EditorAppearanceMode.auto,
                      label: Text('Auto'),
                      icon: Icon(Icons.brightness_auto_outlined),
                    ),
                  ],
                  selected: {viewModel.appearanceMode},
                  onSelectionChanged: (selection) =>
                      viewModel.updateAppearanceMode(selection.first),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
