import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ColorPickerDialog extends StatefulWidget {
  const ColorPickerDialog({super.key, required this.initialColor});

  final Color initialColor;

  @override
  State<ColorPickerDialog> createState() => ColorPickerDialogState();
}

class ColorPickerDialogState extends State<ColorPickerDialog> {
  static const _families = <MaterialColor>[
    Colors.grey,
    Colors.red,
    Colors.orange,
    Colors.amber,
    Colors.green,
    Colors.teal,
    Colors.blue,
    Colors.indigo,
    Colors.purple,
    Colors.pink,
  ];
  static const _shades = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900];

  late Color _selectedColor;
  late final TextEditingController _hexController;
  int _mode = 0;
  // Nine levels controlling shade distribution, with a fixed lightest shade.
  static const _gridToneLimit = 0.4;
  double? _gridTone;

  double _snapGridTone(double value) =>
      (value.clamp(-_gridToneLimit, _gridToneLimit) * 10).round() / 10;
  late final List<TextEditingController> _rgbControllers;
  final List<String?> _rgbErrors = [null, null, null];

  void _syncRgb() {
    final argb = _selectedColor.toARGB32();
    for (var i = 0; i < 3; i++) {
      _rgbControllers[i].text = ((argb >> (16 - i * 8)) & 255).toString();
      _rgbErrors[i] = null;
    }
  }

  void _onRgbChanged() {
    final values = <int>[];
    setState(() {
      for (var i = 0; i < 3; i++) {
        final text = _rgbControllers[i].text.trim();
        final value = RegExp(r'^\d{1,3}$').hasMatch(text)
            ? int.tryParse(text)
            : null;
        _rgbErrors[i] = value == null || value > 255 ? 'Use 0–255' : null;
        values.add(value ?? 0);
      }
      if (_rgbErrors.every((error) => error == null)) {
        _selectedColor = Color.fromARGB(255, values[0], values[1], values[2]);
        _pickerColor = HSVColor.fromColor(_selectedColor);
        _baseColor = HSLColor.fromColor(_selectedColor);
        _hexController.text = _hex(_selectedColor);
        _hexError = null;
      }
    });
  }

  bool get _invalidInput =>
      _hexError != null || _rgbErrors.any((error) => error != null);

  Color _gridColor(MaterialColor family, int row, double tone) {
    final color = family[_shades[row]]!;
    if (tone == 0 || row == 0) return color;

    // Scale the dark-to-light ratio relative to the fixed lightest swatch.
    // At the darkest step, each shade has 4x its original darkness ratio.
    // This also darkens the final row without flattening shades to black.
    final hsl = HSLColor.fromColor(color);
    final anchor = HSLColor.fromColor(family[_shades.first]!).lightness;
    final light = (hsl.lightness / anchor).clamp(0.0, 1.0);
    final multiplier = math.pow(4, -tone / _gridToneLimit).toDouble();
    final adjusted = light / (light + multiplier * (1 - light));
    return hsl.withLightness((anchor * adjusted).clamp(0.0, 1.0)).toColor();
  }

  String _gridToneLabel(double value) {
    if (value == 0) return 'Original · 1×';
    final multiplier = math.pow(4, value.abs() / _gridToneLimit);
    return '${value < 0 ? 'Darker' : 'Lighter'} · ${multiplier.toStringAsFixed(1)}×';
  }

  late HSVColor _pickerColor;
  late HSLColor _baseColor;
  SharedPreferences? _preferences;
  List<Color> _recentColors = [];
  List<Color> _savedColors = [];

  Future<void> _loadPalette() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    List<Color> read(String key) => [
      for (final value in preferences.getStringList(key) ?? <String>[])
        if (int.tryParse(value) case final int argb) Color(argb),
    ];
    setState(() {
      _preferences = preferences;
      _recentColors = read('colorPicker.recent');
      _savedColors = read('colorPicker.saved');
      final savedTone = preferences.getDouble('colorPicker.gridTone');
      if (savedTone != null) _gridTone ??= _snapGridTone(savedTone);
    });
  }

  Future<void> _saveColors(String key, List<Color> colors) async {
    await _preferences?.setStringList(
      key,
      colors.map((color) => color.toARGB32().toString()).toList(),
    );
  }

  Future<void> _useColor() async {
    final color = _selectedColor;
    final recent = [
      color,
      ..._recentColors.where((entry) => entry.toARGB32() != color.toARGB32()),
    ].take(12).toList();
    await _saveColors('colorPicker.recent', recent);
    if (mounted) Navigator.of(context).pop(color);
  }

  void _toggleSaved() {
    final exists = _savedColors.any(
      (color) => color.toARGB32() == _selectedColor.toARGB32(),
    );
    setState(() {
      _savedColors = exists
          ? _savedColors
                .where((color) => color.toARGB32() != _selectedColor.toARGB32())
                .toList()
          : [..._savedColors, _selectedColor];
    });
    _saveColors('colorPicker.saved', _savedColors);
  }

  Widget _palette(List<Color> colors) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final color in colors)
        SizedBox(width: 30, height: 30, child: _swatch(color)),
    ],
  );
  String? _hexError;

  String _hex(Color color) => color
      .toARGB32()
      .toRadixString(16)
      .padLeft(8, '0')
      .substring(2)
      .toUpperCase();

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
    _pickerColor = HSVColor.fromColor(_selectedColor);
    _hexController = TextEditingController(text: _hex(_selectedColor));
    _baseColor = HSLColor.fromColor(_selectedColor);
    _rgbControllers = List.generate(3, (_) => TextEditingController());
    _syncRgb();
    _loadPalette();
  }

  @override
  void dispose() {
    _hexController.dispose();
    for (final controller in _rgbControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _selectColor(Color color, {bool updateBase = true, HSVColor? hsvColor}) {
    setState(() {
      _selectedColor = color;
      _pickerColor = hsvColor ?? HSVColor.fromColor(color);
      if (updateBase) _baseColor = HSLColor.fromColor(color);
      _hexController.text = _hex(color);
      _hexError = null;
      _syncRgb();
    });
  }

  void _onHexChanged(String value) {
    final hex = value.trim().replaceFirst(RegExp(r'^#'), '');
    final valid = RegExp(r'^(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})$').hasMatch(hex);
    setState(() {
      _hexError = valid ? null : 'Enter 3 or 6 hexadecimal digits.';
      if (valid) {
        final expanded = hex.length == 3
            ? hex.split('').map((digit) => '$digit$digit').join()
            : hex;
        _selectedColor = Color(0xFF000000 | int.parse(expanded, radix: 16));
        _baseColor = HSLColor.fromColor(_selectedColor);
        _pickerColor = HSVColor.fromColor(_selectedColor);
        _syncRgb();
      }
    });
  }

  Widget _hueBar(double hue, ValueChanged<double> onChanged) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 32,
        trackShape: const _HueTrackShape(),
        thumbColor: HSLColor.fromAHSL(1, hue, 1, 0.5).toColor(),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
      ),
      child: Slider(
        value: hue,
        min: 0,
        max: 360,
        label: '${hue.round()}°',
        semanticFormatterCallback: (value) => 'Hue ${value.round()} degrees',
        onChanged: onChanged,
      ),
    );
  }

  Widget _swatch(Color color, {bool updateBase = true}) {
    final selected = color.toARGB32() == _selectedColor.toARGB32();
    final label = '#${_hex(color)}';
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: () => _selectColor(color, updateBase: updateBase),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.black26,
                width: selected ? 3 : 0.5,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: selected
                ? Icon(
                    Icons.check,
                    size: 18,
                    color: color.computeLuminance() > 0.45
                        ? Colors.black
                        : Colors.white,
                  )
                : null,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gridTone =
        _gridTone ??
        (Theme.of(context).brightness == Brightness.dark ? -0.2 : 0.2);
    return AlertDialog(
      title: const Text('Choose color'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final entry in [
                    'Grid',
                    'Shades',
                    'Picker',
                    'Values',
                  ].asMap().entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: _mode == entry.key,
                      onSelected: (_) => setState(() {
                        _mode = entry.key;
                        _hexController.text = _hex(_selectedColor);
                        _hexError = null;
                        _syncRgb();
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (_mode == 2) ...[
                AspectRatio(
                  aspectRatio: 1 / 0.7,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ColorPickerArea(
                      _pickerColor,
                      (color) => _selectColor(color.toColor(), hsvColor: color),
                      PaletteType.hsv,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Hue'),
                _hueBar(_pickerColor.hue, (hue) {
                  final color = _pickerColor.withHue(hue);
                  _selectColor(color.toColor(), hsvColor: color);
                }),
              ],
              if (_mode == 0) ...[
                const Text('Choose a shade. Light to dark, top to bottom.'),
                Row(
                  children: [
                    const Text('Darker'),
                    Expanded(
                      child: Slider(
                        value: gridTone,
                        min: -_gridToneLimit,
                        max: _gridToneLimit,
                        divisions: 8,
                        label: _gridToneLabel(gridTone),
                        semanticFormatterCallback: _gridToneLabel,
                        onChanged: (value) =>
                            setState(() => _gridTone = _snapGridTone(value)),
                        onChangeEnd: (value) => _preferences?.setDouble(
                          'colorPicker.gridTone',
                          _snapGridTone(value),
                        ),
                      ),
                    ),
                    const Text('Lighter'),
                    IconButton(
                      tooltip: 'Reset to original shades',
                      onPressed: () {
                        setState(() => _gridTone = 0);
                        _preferences?.setDouble('colorPicker.gridTone', 0);
                      },
                      icon: const Icon(Icons.restart_alt),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: _families.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  children: [
                    for (var row = 0; row < _shades.length; row++)
                      for (final family in _families)
                        _swatch(_gridColor(family, row, gridTone)),
                    _swatch(Colors.white),
                    _swatch(Colors.black),
                  ],
                ),
              ],
              if (_mode == 1) ...[
                const Text('Base hue'),
                const SizedBox(height: 8),
                _hueBar(
                  _baseColor.hue,
                  (hue) => _selectColor(
                    _baseColor
                        .withHue(hue)
                        .withSaturation(
                          _baseColor.saturation == 0
                              ? 0.65
                              : _baseColor.saturation,
                        )
                        .withLightness(0.5)
                        .toColor(),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Color intensity'),
                Slider(
                  value: _baseColor.saturation,
                  label: '${(_baseColor.saturation * 100).round()}%',
                  onChanged: (saturation) => _selectColor(
                    _baseColor.withSaturation(saturation).toColor(),
                  ),
                ),
                const Text('Shades · light to dark'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final lightness in [
                      0.97,
                      0.93,
                      0.85,
                      0.75,
                      0.65,
                      0.55,
                      0.45,
                      0.35,
                      0.25,
                      0.15,
                    ])
                      SizedBox(
                        width: 52,
                        height: 40,
                        child: _swatch(
                          _baseColor.withLightness(lightness).toColor(),
                          updateBase: false,
                        ),
                      ),
                  ],
                ),
              ],
              if (_mode == 3) ...[
                const Text('RGB color · enter values from 0 to 255'),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _rgbControllers[i],
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: ['Red', 'Green', 'Blue'][i],
                            errorText: _rgbErrors[i],
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (_) => _onRgbChanged(),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _hexController,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'Hex color',
                    hintText: '#1A73E8',
                    helperText: 'Use RGB or RRGGBB, with or without #.',
                    errorText: _hexError,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: _onHexChanged,
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _selectedColor,
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text('#${_hex(_selectedColor)}')),
                  IconButton(
                    tooltip: 'Save or remove color',
                    onPressed: _preferences == null || _invalidInput
                        ? null
                        : _toggleSaved,
                    icon: Icon(
                      _savedColors.any(
                            (color) =>
                                color.toARGB32() == _selectedColor.toARGB32(),
                          )
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                    ),
                  ),
                ],
              ),
              if (_recentColors.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Recent colors'),
                const SizedBox(height: 6),
                _palette(_recentColors),
              ],
              const SizedBox(height: 12),
              const Text('Saved colors'),
              const SizedBox(height: 6),
              if (_savedColors.isEmpty)
                const Text('Bookmark a color to reuse it across documents.')
              else
                _palette(_savedColors),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _invalidInput || _preferences == null ? null : _useColor,
          child: const Text('Use color'),
        ),
      ],
    );
  }
}

/// A full-spectrum track that keeps the standard slider's keyboard and drag controls.
class _HueTrackShape extends RoundedRectSliderTrackShape {
  const _HueTrackShape();

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final gradient = LinearGradient(
      colors: [
        for (final hue in [0.0, 60.0, 120.0, 180.0, 240.0, 300.0, 360.0])
          HSLColor.fromAHSL(1, hue, 1, 0.5).toColor(),
      ],
    );
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
      Paint()..shader = gradient.createShader(rect),
    );
  }
}
