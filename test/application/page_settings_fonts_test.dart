import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/application/system_fonts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('legacy favorites migrate into independent lists', () async {
    final font = SystemFonts.encode('Helvetica Neue');
    SharedPreferences.setMockInitialValues({
      'editor.favoriteSystemFonts': [font],
    });
    final document = DocumentSettingsController();
    final controller = PageSettingsController(document);
    await controller.load();
    expect(controller.favoriteFonts(PageFontRole.body), [font]);
    expect(controller.favoriteFonts(PageFontRole.headings), [font]);
    await controller.toggleFavoriteFont(font, PageFontRole.body);
    await controller.load();
    expect(controller.favoriteFonts(PageFontRole.body), isEmpty);
    expect(controller.favoriteFonts(PageFontRole.headings), [font]);
    controller.dispose();
    document.dispose();
  });

  test('favorites survive reload and can be removed', () async {
    final document = DocumentSettingsController();
    final controller = PageSettingsController(document);
    final font = SystemFonts.encode('Helvetica Neue');
    await controller.toggleFavoriteFont(font, PageFontRole.body);
    final restored = PageSettingsController(document);
    await restored.load();
    expect(restored.favoriteFonts(PageFontRole.body), [font]);
    expect(restored.favoriteFonts(PageFontRole.headings), isEmpty);
    await restored.toggleFavoriteFont(font, PageFontRole.headings);
    await restored.toggleFavoriteFont(font, PageFontRole.body);
    final reloaded = PageSettingsController(document);
    await reloaded.load();
    expect(reloaded.favoriteFonts(PageFontRole.body), isEmpty);
    expect(reloaded.favoriteFonts(PageFontRole.headings), [font]);
    controller.dispose();
    restored.dispose();
    reloaded.dispose();
    document.dispose();
  });

  test(
    'system font selection survives theme persistence and resolves locally',
    () async {
      final document = DocumentSettingsController();
      final controller = PageSettingsController(document);
      final font = SystemFonts.encode('Helvetica Neue');
      controller.updateBodyFont(font);
      controller.updateHeadingsFont(font);
      await controller.addCurrentTheme('Local fonts');
      final restored = PageSettingsController(document);
      await restored.load();
      restored.applyTheme(
        restored.themes.singleWhere((theme) => theme.name == 'Local fonts'),
      );
      expect(restored.bodyFont, font);
      expect(restored.headingsFont, font);
      expect(restored.bodyFontFamily, 'Helvetica Neue');
      expect(restored.headingsFontFamily, 'Helvetica Neue');
      expect(SystemFonts.label(font), 'Helvetica Neue');
      controller.dispose();
      restored.dispose();
      document.dispose();
    },
  );
}
