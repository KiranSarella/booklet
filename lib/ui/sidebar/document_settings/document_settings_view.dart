import 'package:booklet/ui/sidebar/document_settings/document_information_section.dart';
import 'package:booklet/ui/sidebar/document_settings/deleted_items_section.dart';
import 'package:booklet/ui/sidebar/document_settings/daily_snapshots_section.dart';
import 'package:flutter/material.dart';
import 'package:booklet/ui/sidebar/document_settings/html_import_dialog.dart';
import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/ui/sidebar/document_settings/document_settings_vm.dart';

class DocumentSettingsView extends StatelessWidget {
  const DocumentSettingsView({super.key, required this.viewModel});

  final DocumentSettingsVM viewModel;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        viewModel.settingsController,
        viewModel.editorController,
      ]),
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Import from', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: viewModel.importMarkdown,
                icon: const Icon(Icons.description_outlined),
                label: const Text('Markdown'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: viewModel.settingsController.isReadOnly
                    ? null
                    : () => showDialog<void>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => HtmlImportDialog(
                          controller: viewModel.editorController,
                        ),
                      ),
                icon: const Icon(Icons.code),
                label: const Text('HTML'),
              ),
            ),
            const SizedBox(height: 20),
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
                  // ButtonSegment(
                  //   value: DocumentAppearanceMode.gray,
                  //   tooltip: 'Gray',
                  //   icon: Icon(Icons.brightness_6_outlined),
                  // ),
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
            DocumentInformationSection(controller: viewModel.editorController),
            DailySnapshotsSection(controller: viewModel.editorController),
            DeletedItemsSection(controller: viewModel.editorController),
          ],
        ),
      ),
    );
  }
}
