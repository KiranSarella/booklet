import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/editor_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/ui/detail/editor/editor_view.dart';
import 'package:booklet/ui/detail/editor/page_view/page_view.dart' as editor;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Wide removes editor canvas spacing and width limit', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final document = DocumentSettingsController();
    final theme = PageSettingsController(document);
    final controller = EditorController(theme, document);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [FlutterQuillLocalizations.delegate],
        home: Scaffold(body: EditorView(controller: controller)),
      ),
    );
    final scroll = find
        .ancestor(
          of: find.byType(editor.PageView),
          matching: find.byType(SingleChildScrollView),
        )
        .first;
    expect(
      tester.widget<SingleChildScrollView>(scroll).padding,
      isNot(EdgeInsets.zero),
    );
    theme.updatePageWidth(PageWidth.wide);
    await tester.pump();
    expect(
      tester.widget<SingleChildScrollView>(scroll).padding,
      EdgeInsets.zero,
    );
    final page = find.descendant(
      of: find.byType(editor.PageView),
      matching: find.byType(Container),
    ).first;
    expect(tester.getTopLeft(page), Offset.zero);
    expect(tester.getSize(page).width, 1400);
    theme.updatePageWidth(PageWidth.normal);
    await tester.pump();
    expect(
      tester.widget<SingleChildScrollView>(scroll).padding,
      isNot(EdgeInsets.zero),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    theme.dispose();
    document.dispose();
  });
}
