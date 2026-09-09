import 'package:flutter/material.dart';

class EditorTheme extends ChangeNotifier {
  EditorTheme({
    Color? titleColor,
    Color? heading1Color,
    Color? heading2Color,
    Color? subheading1Color,
    Color? subheading2Color,
    Color? subheading3Color,
    Color? textColor,
  }) : titleColor = titleColor ?? const Color(0xFF0E0000),
       heading1Color = heading1Color ?? const Color(0xFF081CFE),
       heading2Color = heading2Color ?? const Color(0xFF081CFE),
       subheading1Color = subheading1Color ?? const Color(0xFF05E0B1),
       subheading2Color = subheading2Color ?? const Color(0xFFFCDB04),
       subheading3Color = subheading3Color ?? const Color(0xFFF88010),
       textColor = textColor ?? const Color(0xFF000800);

  Color titleColor;
  Color heading1Color;
  Color heading2Color;
  Color subheading1Color;
  Color subheading2Color;
  Color subheading3Color;
  Color textColor;

  void updateTitleColor(Color color) => _update(() => titleColor = color);
  void updateHeading1Color(Color color) => _update(() => heading1Color = color);
  void updateHeading2Color(Color color) => _update(() => heading2Color = color);
  void updateSubheading1Color(Color color) =>
      _update(() => subheading1Color = color);
  void updateSubheading2Color(Color color) =>
      _update(() => subheading2Color = color);
  void updateSubheading3Color(Color color) =>
      _update(() => subheading3Color = color);
  void updateTextColor(Color color) => _update(() => textColor = color);

  void _update(VoidCallback update) {
    update();
    notifyListeners();
  }
}

class EditorThemeDialog extends StatelessWidget {
  const EditorThemeDialog({super.key, required this.editorTheme});

  final EditorTheme editorTheme;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editor theme'),
      content: SizedBox(
        width: 360,
        child: ListenableBuilder(
          listenable: editorTheme,
          builder: (context, _) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ThemeColorRow(
                  label: 'Title',
                  color: editorTheme.titleColor,
                  onChanged: editorTheme.updateTitleColor,
                ),
                _ThemeColorRow(
                  label: 'Heading 1',
                  color: editorTheme.heading1Color,
                  onChanged: editorTheme.updateHeading1Color,
                ),
                _ThemeColorRow(
                  label: 'Heading 2',
                  color: editorTheme.heading2Color,
                  onChanged: editorTheme.updateHeading2Color,
                ),
                _ThemeColorRow(
                  label: 'Subheading 1',
                  color: editorTheme.subheading1Color,
                  onChanged: editorTheme.updateSubheading1Color,
                ),
                _ThemeColorRow(
                  label: 'Subheading 2',
                  color: editorTheme.subheading2Color,
                  onChanged: editorTheme.updateSubheading2Color,
                ),
                _ThemeColorRow(
                  label: 'Subheading 3',
                  color: editorTheme.subheading3Color,
                  onChanged: editorTheme.updateSubheading3Color,
                ),
                _ThemeColorRow(
                  label: 'Text',
                  color: editorTheme.textColor,
                  onChanged: editorTheme.updateTextColor,
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
      subtitle: Text(_colorValue(color)),
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
      builder: (context) => _ColorPickerDialog(initialColor: color),
    );
    if (selectedColor != null) {
      onChanged(selectedColor);
    }
  }

  String _colorValue(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }
}

class _ColorPickerDialog extends StatelessWidget {
  const _ColorPickerDialog({required this.initialColor});

  final Color initialColor;

  static const _colors = [
    Colors.black,
    Colors.white,
    Colors.red,
    Colors.pink,
    Colors.orange,
    Colors.amber,
    Colors.yellow,
    Colors.lime,
    Colors.green,
    Colors.teal,
    Colors.cyan,
    Colors.lightBlue,
    Colors.blue,
    Colors.indigo,
    Colors.purple,
    Colors.deepPurple,
    Color(0xFF263238),
    Color(0xFF455A64),
    Color(0xFF795548),
    Color(0xFF607D8B),
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose color'),
      content: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final color in _colors)
            InkWell(
              onTap: () => Navigator.of(context).pop(color),
              borderRadius: BorderRadius.circular(20),
              child: CircleAvatar(
                radius: 17,
                backgroundColor: color,
                child: color.toARGB32() == initialColor.toARGB32()
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}
