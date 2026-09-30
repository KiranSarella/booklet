import 'package:flutter/material.dart';
import 'package:booklet/application/appearance_mode.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/ui/page_settings/page_settings_vm.dart';
import 'package:booklet/ui/_helpers/color_picker_dialog.dart';

class PageSettingsDialog extends StatelessWidget {
  const PageSettingsDialog({super.key, required this.viewModel});

  final PageSettingsVM viewModel;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Page settings'),
      content: SizedBox(
        width: 360,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            viewModel.pageSettingsController,
            viewModel.documentSettingsController,
          ]),
          builder: (context, _) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Font size'),
                  // subtitle: Text('${viewModel.baseFontSize.toInt()} px'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Decrease font size',
                        onPressed: viewModel.decreaseFontSize,
                        icon: const Icon(Icons.remove),
                      ),
                      IconButton(
                        tooltip: 'Increase font size',
                        onPressed: viewModel.increaseFontSize,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Page width',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<PageWidth>(
                    segments: [
                      const ButtonSegment(
                        value: PageWidth.normal,
                        label: Text('Normal'),
                        icon: Icon(Icons.crop_portrait_outlined),
                      ),
                      const ButtonSegment(
                        value: PageWidth.wide,
                        label: Text('Wide'),
                        icon: Icon(Icons.crop_landscape_outlined),
                      ),
                      ButtonSegment(
                        value: PageWidth.twoColumns,
                        label: const Text('Columns'),
                        icon: const Icon(Icons.view_column_outlined),
                        enabled: viewModel.isTwoColumnsAvailable,
                      ),
                    ],
                    selected: {viewModel.pageWidth},
                    onSelectionChanged: (selection) {
                      viewModel.updatePageWidth(selection.first);
                    },
                  ),
                ),
                if (!viewModel.isTwoColumnsAvailable)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Two columns is available only in read-only mode.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Page Theme',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
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
                    onSelectionChanged: (selection) {
                      viewModel.updateAppearanceMode(selection.first);
                    },
                  ),
                ),


                const SizedBox(height: 12),

                _ThemeColorRow(
                  label: 'Page background',
                  color: viewModel.pageBackgroundColor,
                  onChanged: viewModel.updatePageBackgroundColor,
                ),
                
                _ThemeColorRow(
                  label: 'Text',
                  color: viewModel.textColor,
                  onChanged: viewModel.updateTextColor,
                ),
                
                _ThemeColorRow(
                  label: 'Headings',
                  color: viewModel.headingColor,
                  onChanged: viewModel.updateHeadingColor,
                ),
                
              ],
            ),
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

class _ThemeColorRow extends StatelessWidget {
  const _ThemeColorRow({
    required this.label,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      // subtitle: Text(_colorValue(color)),
      trailing: InkWell(
        onTap: () => _showColorPicker(context),
        borderRadius: BorderRadius.circular(20),
        child: CircleAvatar(backgroundColor: color, radius: 16),
      ),
    );
  }

  Future<void> _showColorPicker(BuildContext context) async {
    final selectedColor = await showDialog<Color>(
      context: context,
      builder: (context) => ColorPickerDialog(initialColor: color),
    );
    if (selectedColor != null) {
      onChanged(selectedColor);
    }
  }


}
