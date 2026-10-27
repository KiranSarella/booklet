import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/editor_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/detail/editor/editor_view.dart';
import 'package:booklet/ui/detail/editor/table_of_contents_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('outline nests headings, refreshes edits, and navigates', (
    tester,
  ) async {
    final settings = DocumentSettingsController();
    final theme = PageSettingsController(settings);
    final controller = EditorController(theme, settings);
    ComponentBox add(String type, String text) {
      final box = controller.viewModel.createComponentBelowType(
        controller.viewModel.components.length - 1,
        type,
      );
      (box.component.state as TextComponentState).controller.document.insert(
        0,
        text,
      );
      return box;
    }

    add('title', 'Chapter');
    add('heading', 'Section');
    final target = add('subheading', 'Topic');
    add('text', 'Not an outline entry');
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [FlutterQuillLocalizations.delegate],
        home: Scaffold(body: EditorView(controller: controller)),
      ),
    );
    final previousSelection = controller.viewModel.selectedComponent;
    await tester.tap(find.byTooltip('Table of contents'));
    await tester.pumpAndSettle();
    final entries = tester
        .widgetList<PopupMenuItem<ComponentBox>>(
          find.byType(PopupMenuItem<ComponentBox>),
        )
        .where((entry) => entry.enabled)
        .toList();
    expect(entries.map((entry) => (entry.child! as Padding).padding), [
      const EdgeInsets.only(left: 0),
      const EdgeInsets.only(left: 20),
      const EdgeInsets.only(left: 40),
    ]);
    await tester.tap(
      find.descendant(
        of: find.byType(PopupMenuItem<ComponentBox>),
        matching: find.text('Topic'),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.viewModel.selectedComponent, same(previousSelection));
    final viewport = tester.getRect(find.byType(EditorView));
    final targetRect = tester.getRect(find.byKey(target.componentKey));
    expect(targetRect.overlaps(viewport), isTrue);

    (target.component.state as TextComponentState).controller.document.insert(
      0,
      'Updated ',
    );
    await tester.tap(find.byType(TableOfContentsButton));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(PopupMenuItem<ComponentBox>),
        matching: find.text('Updated Topic'),
      ),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(790, 590));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    theme.dispose();
    settings.dispose();
  });
}
