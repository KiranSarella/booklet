import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum EditorAppearanceMode { light, dark, auto }

class EditorTheme extends ChangeNotifier {
  EditorTheme({this.baseFontSize = 14})
    : _light = _Palette.light(),
      _dark = _Palette.dark();

  static const _appearanceModeKey = 'editor.appearanceMode';
  static const _baseFontSizeKey = 'editor.baseFontSize';
  static const _paletteKeyPrefix = 'editor.palette';

  final _preferences = SharedPreferences.getInstance();
  final _Palette _light;
  final _Palette _dark;
  double baseFontSize;
  EditorAppearanceMode _appearanceMode = EditorAppearanceMode.auto;
  Brightness _systemBrightness = Brightness.light;

  EditorAppearanceMode get appearanceMode => _appearanceMode;
  ThemeMode get themeMode => switch (_appearanceMode) {
    EditorAppearanceMode.light => ThemeMode.light,
    EditorAppearanceMode.dark => ThemeMode.dark,
    EditorAppearanceMode.auto => ThemeMode.system,
  };
  Brightness get effectiveBrightness =>
      _appearanceMode == EditorAppearanceMode.auto
      ? _systemBrightness
      : _appearanceMode == EditorAppearanceMode.dark
      ? Brightness.dark
      : Brightness.light;

  _Palette get _activePalette =>
      effectiveBrightness == Brightness.dark ? _dark : _light;

  Color get titleColor => _activePalette.titleColor;
  Color get headingColor => _activePalette.headingColor;
  Color get subheadingColor => _activePalette.subheadingColor;
  Color get textColor => _activePalette.textColor;
  Color get pageBackgroundColor => _activePalette.pageBackgroundColor;

  void updateTitleColor(Color color) =>
      _update(() => _activePalette.titleColor = color);
  void updateHeadingColor(Color color) =>
      _update(() => _activePalette.headingColor = color);
  void updateSubheadingColor(Color color) =>
      _update(() => _activePalette.subheadingColor = color);
  void updateTextColor(Color color) =>
      _update(() => _activePalette.textColor = color);
  void updatePageBackgroundColor(Color color) =>
      _update(() => _activePalette.pageBackgroundColor = color);
  void updateAppearanceMode(EditorAppearanceMode mode) =>
      _update(() => _appearanceMode = mode);
  void updateSystemBrightness(Brightness brightness) {
    if (_systemBrightness == brightness) {
      return;
    }
    _systemBrightness = brightness;
    notifyListeners();
  }

  void increaseFontSize() => _update(() => baseFontSize += 2);
  void decreaseFontSize() => _update(
    () => baseFontSize = baseFontSize > 2 ? baseFontSize - 2 : baseFontSize,
  );

  Future<void> load() async {
    final preferences = await _preferences;
    final savedMode = preferences.getString(_appearanceModeKey);
    _appearanceMode = EditorAppearanceMode.values.firstWhere(
      (mode) => mode.name == savedMode,
      orElse: () => EditorAppearanceMode.auto,
    );
    baseFontSize = preferences.getDouble(_baseFontSizeKey) ?? baseFontSize;
    _light.load(preferences, '$_paletteKeyPrefix.light');
    _dark.load(preferences, '$_paletteKeyPrefix.dark');
    notifyListeners();
  }

  void _update(VoidCallback update) {
    update();
    notifyListeners();
    _persist();
  }

  Future<void> _persist() async {
    final preferences = await _preferences;
    await preferences.setString(_appearanceModeKey, _appearanceMode.name);
    await preferences.setDouble(_baseFontSizeKey, baseFontSize);
    _light.save(preferences, '$_paletteKeyPrefix.light');
    _dark.save(preferences, '$_paletteKeyPrefix.dark');
  }
}

class _Palette {
  _Palette({
    required this.titleColor,
    required this.headingColor,
    required this.subheadingColor,
    required this.textColor,
    required this.pageBackgroundColor,
  });

  factory _Palette.light() => _Palette(
    titleColor: const Color(0xFF0E0000),
    headingColor: const Color(0xFF081CFE),
    subheadingColor: const Color(0xFF05E0B1),
    textColor: const Color(0xFF000800),
    pageBackgroundColor: Colors.white,
  );

  factory _Palette.dark() => _Palette(
    titleColor: const Color(0xFFF5F5F5),
    headingColor: const Color(0xFF90CAF9),
    subheadingColor: const Color(0xFF80CBC4),
    textColor: const Color(0xFFF5F5F5),
    pageBackgroundColor: const Color(0xFF121212),
  );

  Color titleColor;
  Color headingColor;
  Color subheadingColor;
  Color textColor;
  Color pageBackgroundColor;

  void load(SharedPreferences preferences, String prefix) {
    titleColor = _readColor(preferences, '$prefix.title', titleColor);
    headingColor = _readColor(preferences, '$prefix.heading', headingColor);
    subheadingColor = _readColor(
      preferences,
      '$prefix.subheading',
      subheadingColor,
    );
    textColor = _readColor(preferences, '$prefix.text', textColor);
    pageBackgroundColor = _readColor(
      preferences,
      '$prefix.pageBackground',
      pageBackgroundColor,
    );
  }

  void save(SharedPreferences preferences, String prefix) {
    preferences.setInt('$prefix.title', titleColor.toARGB32());
    preferences.setInt('$prefix.heading', headingColor.toARGB32());
    preferences.setInt('$prefix.subheading', subheadingColor.toARGB32());
    preferences.setInt('$prefix.text', textColor.toARGB32());
    preferences.setInt(
      '$prefix.pageBackground',
      pageBackgroundColor.toARGB32(),
    );
  }

  Color _readColor(SharedPreferences preferences, String key, Color fallback) {
    final value = preferences.getInt(key);
    return value == null ? fallback : Color(value);
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Appearance',
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
                    selected: {editorTheme.appearanceMode},
                    onSelectionChanged: (selection) {
                      editorTheme.updateAppearanceMode(selection.first);
                    },
                  ),
                ),
                const SizedBox(height: 12),
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
                _ThemeColorRow(
                  label: 'Page background',
                  color: editorTheme.pageBackgroundColor,
                  onChanged: editorTheme.updatePageBackgroundColor,
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
