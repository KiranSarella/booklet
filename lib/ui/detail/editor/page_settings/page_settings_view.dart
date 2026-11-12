import 'package:flutter/material.dart';
import 'package:booklet/application/system_fonts.dart';
import 'package:booklet/application/appearance_mode.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/ui/detail/editor/page_settings/page_settings_vm.dart';
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
                // ListTile(
                //   contentPadding: EdgeInsets.zero,
                //   title: const Text('Font size'),
                //   // subtitle: Text('${viewModel.baseFontSize.toInt()} px'),
                //   trailing: Row(
                //     mainAxisSize: MainAxisSize.min,
                //     children: [
                //       IconButton(
                //         tooltip: 'Decrease font size',
                //         onPressed: viewModel.decreaseFontSize,
                //         icon: const Icon(Icons.remove),
                //       ),
                //       IconButton(
                //         tooltip: 'Increase font size',
                //         onPressed: viewModel.increaseFontSize,
                //         icon: const Icon(Icons.add),
                //       ),
                //     ],
                //   ),
                // ),
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

                _ThemeColorRow(
                  label: 'Style',
                  color: viewModel.styleColor,
                  onChanged: viewModel.updateStyleColor,
                ),
                _FontPicker(
                  label: 'Body font',
                  role: PageFontRole.body,
                  controller: viewModel.pageSettingsController,
                  value: viewModel.bodyFont,
                  options: PageColorTheme.bodyFontOptions,
                  onChanged: viewModel.updateBodyFont,
                ),
                _FontPicker(
                  label: 'Headings font',
                  role: PageFontRole.headings,
                  controller: viewModel.pageSettingsController,
                  value: viewModel.headingsFont,
                  options: PageColorTheme.headingsFontOptions,
                  onChanged: viewModel.updateHeadingsFont,
                ),
                const SizedBox(height: 16),
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Themes',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Save current colors and fonts as a theme',
                      onPressed: () => _addTheme(context),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                for (final theme in viewModel.themes)
                  Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      dense: true,
                      onTap: () => viewModel.applyTheme(theme),
                      title: Text(theme.name),
                      leading: _ThemeSwatches(theme: theme),
                      trailing: theme.isDefault
                          ? null
                          : IconButton(
                              tooltip: 'Delete ${theme.name}',
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => viewModel.deleteTheme(theme),
                            ),
                    ),
                  ),
                const SizedBox(height: 16),
                const Divider(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Typography',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 12),
                _SpacingSlider(
                  label: 'Letter spacing',
                  value: viewModel.letterSpacing,
                  min: -1,
                  max: 5,
                  divisions: 60,
                  unit: 'px',
                  onChanged: viewModel.updateLetterSpacing,
                ),
                _SpacingSlider(
                  label: 'Word spacing',
                  value: viewModel.wordSpacing,
                  min: 0,
                  max: 12,
                  divisions: 48,
                  unit: 'px',
                  onChanged: viewModel.updateWordSpacing,
                ),
                _SpacingSlider(
                  label: 'Line height',
                  value: viewModel.lineHeight ?? 1.5,
                  min: 1,
                  max: 2.5,
                  divisions: 30,
                  unit: '×',
                  automatic: viewModel.lineHeight == null,
                  onChanged: viewModel.updateLineHeight,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: viewModel.resetAdvancedTypography,
                    child: const Text('Reset typography'),
                  ),
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

  Future<void> _addTheme(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _SaveThemeDialog(),
    );
    final trimmedName = name?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) {
      await viewModel.addCurrentTheme(trimmedName);
    }
  }
}

class _SaveThemeDialog extends StatefulWidget {
  const _SaveThemeDialog();

  @override
  State<_SaveThemeDialog> createState() => _SaveThemeDialogState();
}

class _SaveThemeDialogState extends State<_SaveThemeDialog> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop(_nameController.text);

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Save theme'),
    content: TextField(
      controller: _nameController,
      autofocus: true,
      decoration: const InputDecoration(labelText: 'Theme name'),
      onSubmitted: (_) => _save(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save')),
    ],
  );
}

class _ThemeSwatches extends StatelessWidget {
  const _ThemeSwatches({required this.theme});

  final PageColorTheme theme;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _ThemeSwatch(color: theme.pageBackgroundColor),
      _ThemeSwatch(color: theme.textColor),
      _ThemeSwatch(color: theme.headingColor),
      _ThemeSwatch(color: theme.styleColor),
    ],
  );
}

class _FontPicker extends StatelessWidget {
  const _FontPicker({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.controller,
    required this.role,
  });

  final PageFontRole role;
  final String label, value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final PageSettingsController controller;
  static const _chooseFonts = '__choose_system_fonts__';

  Future<void> _choose(BuildContext context) async {
    final font = await showDialog<String>(
      context: context,
      builder: (_) => _SystemFontDialog(
        controller: controller,
        selected: value,
        role: role,
      ),
    );
    if (font != null) onChanged(font);
  }

  @override
  Widget build(BuildContext context) {
    final favorites = controller
        .favoriteFonts(role)
        .where((font) => !options.contains(font))
        .toList();
    final otherSelected =
        !options.contains(value) && !favorites.contains(value);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            items: [
              for (final font in options)
                DropdownMenuItem(
                  value: font,
                  child: Text(SystemFonts.label(font)),
                ),
              if (favorites.isNotEmpty) ...[
                DropdownMenuItem<String>(
                  enabled: false,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Favorites',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                for (final font in favorites)
                  DropdownMenuItem(
                    value: font,
                    child: Text(SystemFonts.label(font)),
                  ),
              ],
              if (otherSelected)
                DropdownMenuItem(
                  value: value,
                  child: Text(SystemFonts.label(value)),
                ),
              DropdownMenuItem(
                value: _chooseFonts,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.font_download_outlined,
                        size: 18,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Choose system fonts…',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            onChanged: (font) {
              if (font == _chooseFonts) {
                _choose(context);
              } else if (font != null) {
                onChanged(font);
              }
            },
          ),
        ),
      ),
    );
  }
}

class _SystemFontDialog extends StatefulWidget {
  const _SystemFontDialog({
    required this.controller,
    required this.selected,
    required this.role,
  });
  final PageFontRole role;
  final PageSettingsController controller;
  final String selected;

  @override
  State<_SystemFontDialog> createState() => _SystemFontDialogState();
}

class _SystemFontDialogState extends State<_SystemFontDialog> {
  late Future<List<String>> _fonts = SystemFonts.availableFamilies();
  String _query = '';

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Row(
      children: [
        const Expanded(child: Text('Choose system fonts')),
        IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
      ],
    ),
    content: SizedBox(
      width: 440,
      height: 440,
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Search fonts',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _query = value.toLowerCase()),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<String>>(
              future: _fonts,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Unable to load system fonts.'),
                        TextButton(
                          onPressed: () => setState(() {
                            _fonts = SystemFonts.availableFamilies();
                          }),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final fonts = snapshot.data!
                    .where((font) => font.toLowerCase().contains(_query))
                    .toList();
                if (fonts.isEmpty) {
                  return const Center(child: Text('No fonts found.'));
                }
                return AnimatedBuilder(
                  animation: widget.controller,
                  builder: (context, _) => ListView.builder(
                    itemCount: fonts.length,
                    itemBuilder: (context, index) {
                      final family = fonts[index];
                      final font = SystemFonts.encode(family);
                      final favorite = widget.controller
                          .favoriteFonts(widget.role)
                          .contains(font);
                      return ListTile(
                        selected: widget.selected == font,
                        title: Text(
                          family,
                          style: TextStyle(fontFamily: family),
                        ),
                        onTap: () => Navigator.of(context).pop(font),
                        trailing: IconButton(
                          tooltip: favorite
                              ? 'Unfavorite $family'
                              : 'Favorite $family',
                          icon: Icon(favorite ? Icons.star : Icons.star_border),
                          onPressed: () => widget.controller.toggleFavoriteFont(
                            font,
                            widget.role,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 13,
    height: 13,
    margin: const EdgeInsets.only(right: 3),
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
  );
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

class _SpacingSlider extends StatelessWidget {
  const _SpacingSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.unit,
    required this.onChanged,
    this.automatic = false,
  });

  final String label;
  final double value, min, max;
  final int divisions;
  final String unit;
  final bool automatic;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final display = automatic ? 'Default' : '${value.toStringAsFixed(2)} $unit';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('$label: $display'),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: display,
          semanticFormatterCallback: (value) =>
              '${value.toStringAsFixed(2)} $unit',
          onChanged: onChanged,
        ),
      ],
    );
  }
}
