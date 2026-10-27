import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/editor_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/detail/editor/editor_minimap.dart';
import 'package:booklet/ui/detail/editor/editor_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'minimap toggles, navigates without selection, and follows edits',
    (tester) async {
      final settings = DocumentSettingsController();
      final theme = PageSettingsController(settings);
      final controller = EditorController(theme, settings);
      for (var i = 0; i < 18; i++) {
        final box = controller.viewModel.createComponentBelowType(
          controller.viewModel.components.length - 1,
          'heading',
        );
        (box.component.state as TextComponentState).controller.document.insert(
          0,
          'Section $i',
        );
      }
      final target = controller.viewModel.components.last;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [FlutterQuillLocalizations.delegate],
          home: Scaffold(body: EditorView(controller: controller)),
        ),
      );
      expect(find.byType(EditorMinimap), findsNothing);
      await tester.tap(find.byTooltip('Show minimap'));
      await tester.pumpAndSettle();
      expect(find.byType(EditorMinimap), findsOneWidget);
      final selection = controller.viewModel.selectedComponent;
      final minimap = tester.widget<EditorMinimap>(find.byType(EditorMinimap));
      final before = minimap.scrollController.offset;
      await tester.tap(find.bySemanticsLabel('Scroll to Section 17'));
      await tester.pumpAndSettle();
      expect(minimap.scrollController.offset, greaterThan(before));
      expect(controller.viewModel.selectedComponent, same(selection));
      expect(
        tester
            .getRect(find.byKey(target.componentKey))
            .overlaps(tester.getRect(find.byType(EditorView))),
        isTrue,
      );
      (target.component.state as TextComponentState).controller.document.insert(
        0,
        'Updated ',
      );
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Scroll to Updated Section 17'),
        findsOneWidget,
      );
      final mapRect = tester.getRect(find.byType(EditorMinimap));
      await tester.dragFrom(
        Offset(mapRect.center.dx, mapRect.top + 60),
        const Offset(0, 200),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Hide minimap'));
      await tester.pumpAndSettle();
      expect(find.byType(EditorMinimap), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      theme.dispose();
      settings.dispose();
    },
  );
}
