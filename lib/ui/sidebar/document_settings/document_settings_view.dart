import 'package:flutter/material.dart';
import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/ui/sidebar/document_settings/document_settings_vm.dart';

class DocumentSettingsView extends StatelessWidget {
  const DocumentSettingsView({
    super.key,
    required this.viewModel,
    this.fileActions,
  });

  final DocumentSettingsVM viewModel;
  // Temporary file actions (open/save), to be removed later.
  final Widget? fileActions;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewModel.settingsController,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (fileActions != null) ...[
              Text('File', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              fileActions!,
              const SizedBox(height: 20),
            ],
            Text('Mode', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<DocumentEditMode>(
                showSelectedIcon: false,
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
            Text('Appearance', style: Theme.of(context).textTheme.titleSmall),
            // Text(
            //   'Applies to the whole app (navigation, menus). Not the page view.',
            //   style: Theme.of(context).textTheme.bodySmall,
            // ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<DocumentAppearanceMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: DocumentAppearanceMode.light,
                    tooltip: 'Light',
                    icon: Icon(Icons.light_mode_outlined),
                  ),
                  ButtonSegment(
                    value: DocumentAppearanceMode.gray,
                    tooltip: 'Gray',
                    icon: Icon(Icons.brightness_6_outlined),
                  ),
                  ButtonSegment(
                    value: DocumentAppearanceMode.dark,
                    tooltip: 'Dark',
                    icon: Icon(Icons.dark_mode_outlined),
                  ),
                  ButtonSegment(
                    value: DocumentAppearanceMode.auto,
                    tooltip: 'Auto',
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
    );
  }
}
