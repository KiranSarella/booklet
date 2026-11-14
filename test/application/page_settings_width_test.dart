import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final tablet in [false, true]) {
    test('default width for tablet=$tablet survives loading', () async {
      final document = DocumentSettingsController();
      final page = PageSettingsController(document, isAndroidTablet: tablet);
      addTearDown(page.dispose);
      addTearDown(document.dispose);
      expect(page.pageWidth, tablet ? PageWidth.wide : PageWidth.normal);
      await page.load();
      expect(page.pageWidth, tablet ? PageWidth.wide : PageWidth.normal);
      expect(page.fillsViewport, tablet);
    });
  }

  test('saved Normal overrides tablet default', () async {
    SharedPreferences.setMockInitialValues({'editor.pageWidth': 'normal'});
    final document = DocumentSettingsController();
    final page = PageSettingsController(document, isAndroidTablet: true);
    addTearDown(page.dispose);
    addTearDown(document.dispose);
    await page.load();
    expect(page.pageWidth, PageWidth.normal);
    expect(page.fillsViewport, isFalse);
    page.updatePageWidth(PageWidth.wide);
    expect(page.fillsViewport, isTrue);
  });

  test('Wide fills the viewport even without tablet detection', () {
    final document = DocumentSettingsController();
    final page = PageSettingsController(document);
    addTearDown(page.dispose);
    addTearDown(document.dispose);
    page.updatePageWidth(PageWidth.wide);
    expect(page.fillsViewport, isTrue);
  });

  test('legacy columns selection becomes Wide', () async {
    SharedPreferences.setMockInitialValues({'editor.pageWidth': 'twoColumns'});
    final document = DocumentSettingsController();
    final page = PageSettingsController(document);
    addTearDown(page.dispose);
    addTearDown(document.dispose);
    await page.load();
    expect(page.pageWidth, PageWidth.wide);
  });
}
