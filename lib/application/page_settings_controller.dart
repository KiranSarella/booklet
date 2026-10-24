import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  static const _lightThemesKey = 'editor.themes.light';
  static const _darkThemesKey = 'editor.themes.dark';

  // Secondary appearance: scoped to the page view only. 'auto' follows the
  // primary document appearance instead of the system brightness directly.
  final DocumentSettingsController documentSettingsController;
  final double originalBaseFontSize;
  final _preferences = SharedPreferences.getInstance();
  final _Palette _light;
  final _Palette _dark;
  final List<PageColorTheme> _lightCustomThemes = [];
  final List<PageColorTheme> _darkCustomThemes = [];
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
  String get bodyFont => _activePalette.bodyFont;
  String get headingsFont => _activePalette.headingsFont;
  String? get bodyFontFamily => _resolveFontFamily(bodyFont);
  String? get headingsFontFamily => _resolveFontFamily(headingsFont);
  List<PageColorTheme> get themes => [
    ...PageColorTheme.defaults(effectiveBrightness),
    ..._customThemes,
  ];
  List<PageColorTheme> get _customThemes =>
      effectiveBrightness == Brightness.dark
      ? _darkCustomThemes
      : _lightCustomThemes;

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
  void updateBodyFont(String font) =>
      _update(() => _activePalette.bodyFont = font);
  void updateHeadingsFont(String font) =>
      _update(() => _activePalette.headingsFont = font);
  void updateAppearanceMode(EditorAppearanceMode mode) =>
      _update(() => _appearanceMode = mode);
  void updatePageWidth(PageWidth width) => _update(() => _pageWidth = width);

  void applyTheme(PageColorTheme theme) => _update(() {
    _activePalette.pageBackgroundColor = theme.pageBackgroundColor;
    _activePalette.textColor = theme.textColor;
    _activePalette.headingColor = theme.headingColor;
    _activePalette.styleColor = theme.styleColor;
    _activePalette.bodyFont = theme.bodyFont;
    _activePalette.headingsFont = theme.headingsFont;
  });

  Future<void> addCurrentTheme(String name) async {
    final theme = PageColorTheme(
      name: name,
      pageBackgroundColor: pageBackgroundColor,
      textColor: textColor,
      headingColor: headingColor,
      styleColor: styleColor,
      bodyFont: bodyFont,
      headingsFont: headingsFont,
      isDefault: false,
    );
    _customThemes.add(theme);
    notifyListeners();
    await _persistThemes();
  }

  Future<void> deleteTheme(PageColorTheme theme) async {
    if (theme.isDefault || !_customThemes.remove(theme)) return;
    notifyListeners();
    await _persistThemes();
  }

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
    _loadThemes(preferences.getString(_lightThemesKey), _lightCustomThemes);
    _loadThemes(preferences.getString(_darkThemesKey), _darkCustomThemes);
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

  void _loadThemes(String? stored, List<PageColorTheme> destination) {
    if (stored == null) return;
    try {
      final decoded = jsonDecode(stored) as List<dynamic>;
      destination
        ..clear()
        ..addAll(
          decoded.whereType<Map<String, dynamic>>().map(
            PageColorTheme.fromJson,
          ),
        );
    } on FormatException {
      destination.clear();
    } on TypeError {
      destination.clear();
    }
  }

  Future<void> _persistThemes() async {
    final preferences = await _preferences;
    await preferences.setString(
      _lightThemesKey,
      jsonEncode(_lightCustomThemes.map((theme) => theme.toJson()).toList()),
    );
    await preferences.setString(
      _darkThemesKey,
      jsonEncode(_darkCustomThemes.map((theme) => theme.toJson()).toList()),
    );
  }

  String? _resolveFontFamily(String font) => font == PageColorTheme.systemFont
      ? null
      : GoogleFonts.getFont(font).fontFamily;
}

class PageColorTheme {
  const PageColorTheme({
    required this.name,
    required this.pageBackgroundColor,
    required this.textColor,
    required this.headingColor,
    required this.styleColor,
    required this.bodyFont,
    required this.headingsFont,
    required this.isDefault,
  });

  final String name;
  final Color pageBackgroundColor;
  final Color textColor;
  final Color headingColor;
  final Color styleColor;
  final String bodyFont;
  final String headingsFont;
  final bool isDefault;

  static const systemFont = 'System';
  static const bodyFontOptions = [
    systemFont,
    'Roboto',
    'Open Sans',
    'Lato',
    'Nunito',
    'Source Sans 3',
    'Lora',
  ];
  static const headingsFontOptions = [
    systemFont,
    'Montserrat',
    'Poppins',
    'Playfair Display',
    'Merriweather',
    'Oswald',
    'Raleway',
  ];

  factory PageColorTheme.fromJson(Map<String, dynamic> json) => PageColorTheme(
    name: json['name'] as String,
    pageBackgroundColor: Color(json['pageBackground'] as int),
    textColor: Color(json['text'] as int),
    headingColor: Color(json['headings'] as int),
    styleColor: Color(json['style'] as int),
    bodyFont: json['bodyFont'] as String? ?? systemFont,
    headingsFont: json['headingsFont'] as String? ?? systemFont,
    isDefault: false,
  );

  Map<String, Object> toJson() => {
    'name': name,
    'pageBackground': pageBackgroundColor.toARGB32(),
    'text': textColor.toARGB32(),
    'headings': headingColor.toARGB32(),
    'style': styleColor.toARGB32(),
    'bodyFont': bodyFont,
    'headingsFont': headingsFont,
  };

  static List<PageColorTheme> defaults(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final background = dark ? const Color(0xFF121212) : Colors.white;
    final text = dark ? const Color(0xFFF5F5F5) : const Color(0xFF202124);
    return [
      PageColorTheme(
        name: 'Classic',
        pageBackgroundColor: background,
        textColor: text,
        headingColor: dark ? const Color(0xFF90CAF9) : const Color(0xFF174EA6),
        styleColor: dark ? const Color(0xFF80CBC4) : const Color(0xFF00897B),
        bodyFont: systemFont,
        headingsFont: systemFont,
        isDefault: true,
      ),
      PageColorTheme(
        name: 'Ocean',
        pageBackgroundColor: dark
            ? const Color(0xFF10212B)
            : const Color(0xFFEAF6FA),
        textColor: dark ? const Color(0xFFE3F2FD) : const Color(0xFF183642),
        headingColor: dark ? const Color(0xFF80DEEA) : const Color(0xFF007C91),
        styleColor: dark ? const Color(0xFF4DD0E1) : const Color(0xFF0097A7),
        bodyFont: systemFont,
        headingsFont: systemFont,
        isDefault: true,
      ),
      PageColorTheme(
        name: 'Forest',
        pageBackgroundColor: dark
            ? const Color(0xFF17231B)
            : const Color(0xFFF0F5EC),
        textColor: dark ? const Color(0xFFE8F5E9) : const Color(0xFF26352A),
        headingColor: dark ? const Color(0xFFA5D6A7) : const Color(0xFF2E6B3F),
        styleColor: dark ? const Color(0xFF81C784) : const Color(0xFF558B2F),
        bodyFont: systemFont,
        headingsFont: systemFont,
        isDefault: true,
      ),
    ];
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
    required this.bodyFont,
    required this.headingsFont,
  });

  factory _Palette.light() => _Palette(
    titleColor: const Color(0xFF0E0000),
    headingColor: const Color(0xFF081CFE),
    subheadingColor: const Color(0xFF05E0B1),
    textColor: const Color(0xFF000800),
    styleColor: const Color(0xFF00897B),
    pageBackgroundColor: Colors.white,
    bodyFont: PageColorTheme.systemFont,
    headingsFont: PageColorTheme.systemFont,
  );

  factory _Palette.dark() => _Palette(
    titleColor: const Color(0xFFF5F5F5),
    headingColor: const Color(0xFF90CAF9),
    subheadingColor: const Color(0xFF80CBC4),
    textColor: const Color(0xFFF5F5F5),
    styleColor: const Color(0xFF80CBC4),
    pageBackgroundColor: const Color(0xFF121212),
    bodyFont: PageColorTheme.systemFont,
    headingsFont: PageColorTheme.systemFont,
  );

  Color titleColor;
  Color headingColor;
  Color subheadingColor;
  Color textColor;
  Color styleColor;
  Color pageBackgroundColor;
  String bodyFont;
  String headingsFont;

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
    bodyFont = preferences.getString('$prefix.bodyFont') ?? bodyFont;
    headingsFont =
        preferences.getString('$prefix.headingsFont') ?? headingsFont;
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
    preferences.setString('$prefix.bodyFont', bodyFont);
    preferences.setString('$prefix.headingsFont', headingsFont);
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
