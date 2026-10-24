import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:booklet/application/appearance_mode.dart';
import 'package:booklet/application/document_settings_controller.dart';

enum PageWidth { normal, wide, twoColumns }

class PageSettingsController extends ChangeNotifier {
  PageSettingsController(
    this.documentSettingsController, {
    this.baseFontSize = 14,
  }) : originalBaseFontSize = baseFontSize,
       _light = _Palette.light(),
       _dark = _Palette.dark();

  static const _appearanceModeKey = 'editor.appearanceMode';
  static const _baseFontSizeKey = 'editor.baseFontSize';
  static const _paletteKeyPrefix = 'editor.palette';
  static const _pageWidthKey = 'editor.pageWidth';

  // Secondary appearance: scoped to the page view only. 'auto' follows the
  // primary document appearance instead of the system brightness directly.
  final DocumentSettingsController documentSettingsController;
  final double originalBaseFontSize;
  final _preferences = SharedPreferences.getInstance();
  final _Palette _light;
  final _Palette _dark;
  double baseFontSize;
  EditorAppearanceMode _appearanceMode = EditorAppearanceMode.auto;
  PageWidth _pageWidth = PageWidth.normal;

  EditorAppearanceMode get appearanceMode => _appearanceMode;
  PageWidth get pageWidth => _pageWidth;
  Brightness get effectiveBrightness =>
      _appearanceMode == EditorAppearanceMode.auto
      ? documentSettingsController.effectiveBrightness
      : _appearanceMode == EditorAppearanceMode.dark
      ? Brightness.dark
      : Brightness.light;

  // Two-column layout is not implemented yet; treat it like unconstrained width.
  double? get maxContentWidth => switch (_pageWidth) {
    PageWidth.normal => normalContentWidth,
    PageWidth.wide => wideContentWidth,
    PageWidth.twoColumns => null,
  };

  // Typical desktop document widths (roughly US-Letter proportions at 96dpi).
  static const double normalContentWidth = 840;
  static const double wideContentWidth = 1200;
  static const double _chromeWidth = 500; // navigation panel + page padding
  static const double recommendedWindowHeight = 960;

  double get recommendedWindowWidth =>
      (maxContentWidth ?? wideContentWidth) + _chromeWidth;

  _Palette get _activePalette =>
      effectiveBrightness == Brightness.dark ? _dark : _light;

  Color get titleColor => _activePalette.titleColor;
  Color get headingColor => _activePalette.headingColor;
  Color get subheadingColor => _activePalette.subheadingColor;
  Color get textColor => _activePalette.textColor;
  Color get styleColor => _activePalette.styleColor;
  Color get pageBackgroundColor => _activePalette.pageBackgroundColor;

  void updateTitleColor(Color color) =>
      _update(() => _activePalette.titleColor = color);
  void updateHeadingColor(Color color) =>
      _update(() => _activePalette.headingColor = color);
  void updateSubheadingColor(Color color) =>
      _update(() => _activePalette.subheadingColor = color);
  void updateTextColor(Color color) =>
      _update(() => _activePalette.textColor = color);
  void updateStyleColor(Color color) =>
      _update(() => _activePalette.styleColor = color);
  void updatePageBackgroundColor(Color color) =>
      _update(() => _activePalette.pageBackgroundColor = color);
  void updateAppearanceMode(EditorAppearanceMode mode) =>
      _update(() => _appearanceMode = mode);
  void updatePageWidth(PageWidth width) => _update(() => _pageWidth = width);

  void increaseFontSize() => _update(() => baseFontSize += 2);
  void resetFontSize() => _update(() => baseFontSize = originalBaseFontSize);
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
    final savedWidth = preferences.getString(_pageWidthKey);
    _pageWidth = PageWidth.values.firstWhere(
      (width) => width.name == savedWidth,
      orElse: () => PageWidth.normal,
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
    await preferences.setString(_pageWidthKey, _pageWidth.name);
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
    required this.styleColor,
    required this.pageBackgroundColor,
  });

  factory _Palette.light() => _Palette(
    titleColor: const Color(0xFF0E0000),
    headingColor: const Color(0xFF081CFE),
    subheadingColor: const Color(0xFF05E0B1),
    textColor: const Color(0xFF000800),
    styleColor: const Color(0xFF00897B),
    pageBackgroundColor: Colors.white,
  );

  factory _Palette.dark() => _Palette(
    titleColor: const Color(0xFFF5F5F5),
    headingColor: const Color(0xFF90CAF9),
    subheadingColor: const Color(0xFF80CBC4),
    textColor: const Color(0xFFF5F5F5),
    styleColor: const Color(0xFF80CBC4),
    pageBackgroundColor: const Color(0xFF121212),
  );

  Color titleColor;
  Color headingColor;
  Color subheadingColor;
  Color textColor;
  Color styleColor;
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
    styleColor = _readColor(preferences, '$prefix.style', styleColor);
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
    preferences.setInt('$prefix.style', styleColor.toARGB32());
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
