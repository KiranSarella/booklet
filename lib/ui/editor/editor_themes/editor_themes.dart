import 'package:flutter/material.dart';

class EditorTheme extends ChangeNotifier {
  EditorTheme({
    Color? titleColor,
    Color? headingColor,
    Color? subheadingColor,
    Color? textColor,
    this.baseFontSize = 14,
  }) : titleColor = titleColor ?? const Color(0xFF0E0000),
       headingColor = headingColor ?? const Color(0xFF081CFE),
       subheadingColor = subheadingColor ?? const Color(0xFF05E0B1),
       textColor = textColor ?? const Color(0xFF000800);

  Color titleColor;
  Color headingColor;
  Color subheadingColor;
  Color textColor;
  double baseFontSize;

  void updateTitleColor(Color color) => _update(() => titleColor = color);
  void updateHeadingColor(Color color) => _update(() => headingColor = color);
  void updateSubheadingColor(Color color) =>
      _update(() => subheadingColor = color);
  void updateTextColor(Color color) => _update(() => textColor = color);
    void increaseFontSize() => _update(() => baseFontSize += 2);
    void decreaseFontSize() => _update(() => baseFontSize = baseFontSize > 2
      ? baseFontSize - 2
      : baseFontSize);

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
                  label: 'Heading',
                  color: editorTheme.headingColor,
                  onChanged: editorTheme.updateHeadingColor,
                ),
                _ThemeColorRow(
                  label: 'Subheading',
                  color: editorTheme.subheadingColor,
                  onChanged: editorTheme.updateSubheadingColor,
                ),
                _ThemeColorRow(
                  label: 'Text',
                  color: editorTheme.textColor,
                  onChanged: editorTheme.updateTextColor,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Base font size'),
                  subtitle: Text('${editorTheme.baseFontSize.toInt()} px'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Decrease font size',
                        onPressed: editorTheme.decreaseFontSize,
                        icon: const Icon(Icons.remove),
                      ),
                      IconButton(
                        tooltip: 'Increase font size',
                        onPressed: editorTheme.increaseFontSize,
                        icon: const Icon(Icons.add),
                      ),
                    ],
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
