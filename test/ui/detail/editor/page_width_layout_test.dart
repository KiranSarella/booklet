import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/ui/detail/editor/page_view/page_view.dart' as editor;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final size in [const Size(800, 1280), const Size(1400, 800)]) {
    testWidgets('tablet Wide fills page width at $size', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final document = DocumentSettingsController();
      final settings = PageSettingsController(document)
        ..updatePageWidth(PageWidth.wide);
      addTearDown(settings.dispose);
      addTearDown(document.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: editor.PageView(
              readerLayout: true,
              editorTheme: settings,
              page: null,
              onSelectComponent: (_) {},
              onSelectComponentRange: (_) {},
              onCreateEntryBelow: (_, _) {},
              onBackspaceAtStart: (_) {},
              onPasteText: (_, _) async => false,
              onTapEmptySpace: () {},
              onMoveToAdjacentTextComponent: (_, _) {},
            ),
          ),
        ),
      );
      final page = find.descendant(
        of: find.byType(editor.PageView),
        matching: find.byType(Container),
      );
      expect(tester.getSize(page).width, size.width);
      final container = tester.widget<Container>(page);
      final padding = container.padding!.resolve(TextDirection.ltr);
      expect(padding, const EdgeInsets.all(32));
      expect(padding.left, 32);
      expect(padding.right, 32);
      expect(tester.getTopLeft(page).dx, 0);
      expect(tester.getTopRight(page).dx, size.width);
      settings.updatePageWidth(PageWidth.normal);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
