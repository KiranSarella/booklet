import 'package:flutter/material.dart';
import 'package:booklet/application/appearance_mode.dart';
import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';

class PageSettingsVM {
  PageSettingsVM({
    required this.pageSettingsController,
    required this.documentSettingsController,
  });

  final PageSettingsController pageSettingsController;
  final DocumentSettingsController documentSettingsController;

  EditorAppearanceMode get appearanceMode =>
      pageSettingsController.appearanceMode;
  PageWidth get pageWidth => pageSettingsController.pageWidth;
  bool get isTwoColumnsAvailable => documentSettingsController.isReadOnly;

  Color get titleColor => pageSettingsController.titleColor;
  Color get headingColor => pageSettingsController.headingColor;
  Color get subheadingColor => pageSettingsController.subheadingColor;
  Color get textColor => pageSettingsController.textColor;
  Color get styleColor => pageSettingsController.styleColor;
  Color get pageBackgroundColor => pageSettingsController.pageBackgroundColor;
  double get baseFontSize => pageSettingsController.baseFontSize;
  List<PageColorTheme> get themes => pageSettingsController.themes;

  void updateAppearanceMode(EditorAppearanceMode mode) =>
      pageSettingsController.updateAppearanceMode(mode);
  void updatePageWidth(PageWidth width) =>
      pageSettingsController.updatePageWidth(width);
  void updateTitleColor(Color color) =>
      pageSettingsController.updateTitleColor(color);
  void updateHeadingColor(Color color) =>
      pageSettingsController.updateHeadingColor(color);
  void updateSubheadingColor(Color color) =>
      pageSettingsController.updateSubheadingColor(color);
  void updateTextColor(Color color) =>
      pageSettingsController.updateTextColor(color);
  void updateStyleColor(Color color) =>
      pageSettingsController.updateStyleColor(color);
  void updatePageBackgroundColor(Color color) =>
      pageSettingsController.updatePageBackgroundColor(color);
  void increaseFontSize() => pageSettingsController.increaseFontSize();
  void decreaseFontSize() => pageSettingsController.decreaseFontSize();
  void applyTheme(PageColorTheme theme) =>
      pageSettingsController.applyTheme(theme);
  Future<void> addCurrentTheme(String name) =>
      pageSettingsController.addCurrentTheme(name);
  Future<void> deleteTheme(PageColorTheme theme) =>
      pageSettingsController.deleteTheme(theme);
}
