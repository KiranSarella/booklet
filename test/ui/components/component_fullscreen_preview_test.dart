import 'package:image/image.dart' as image;
import 'package:booklet/ui/components/drawing/drawing_document.dart';
import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/ui/components/component.dart';
import 'package:booklet/ui/components/component_fullscreen_preview.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/drawing_component.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/table_component.dart';
import 'package:booklet/ui/components/table/table_document.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('saved drawing preview displays image with zoom and pan', (
    tester,
  ) async {
    final state = DrawingComponentState();
    state.save([], image.encodePng(image.Image(width: 20, height: 20)));
    await tester.pumpWidget(
      MaterialApp(home: DrawingFullscreenPreview(state: state)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Save'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
  for (final readOnly in [true, false]) {
    for (final kind in ['table', 'drawing']) {
      testWidgets('$kind preview is non-editing with readOnly=$readOnly', (
        tester,
      ) async {
        final Component component = kind == 'table'
            ? TableComponent(id: kind)
            : DrawingComponent(id: kind);
        final document = DocumentSettingsController();
        if (readOnly) document.updateEditMode(DocumentEditMode.readOnly);
        final theme = PageSettingsController(document);
        if (component is TableComponent) {
          component.state.columnWidth = 400;
          for (var i = 0; i < 25; i++) {
            component.state.insertRow(0);
          }
          component.state.rows.last.last.text = 'Last cell';
        }
        final before = component.output;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: component.buildUI(
                  theme: theme,
                  componentState: component.state,
                  isSelected: true,
                  onSelect: () {},
                  onCreateBelow: () {},
                ),
              ),
            ),
          ),
        );
        expect(
          find.text('Edit $kind'),
          readOnly ? findsNothing : findsOneWidget,
        );
        await tester.tap(find.text('Preview $kind'));
        await tester.pumpAndSettle();
        expect(
          find.byType(
            kind == 'table' ? TableFullscreenPreview : DrawingFullscreenPreview,
          ),
          findsOneWidget,
        );
        expect(find.byType(TextField), findsNothing);
        expect(find.text('Save'), findsNothing);
        if (kind == 'table') {
          final preview = tester.widget<TablePreview>(
            find.byType(TablePreview),
          );
          expect(preview.onCell, isNull);
          final scrollables = tester.widgetList<Scrollable>(
            find.descendant(
              of: find.byType(TableFullscreenPreview),
              matching: find.byType(Scrollable),
            ),
          );
          expect(
            scrollables.map((s) => s.axisDirection),
            containsAll([AxisDirection.down, AxisDirection.right]),
          );
          final horizontal = tester
              .widget<Scrollbar>(
                find.descendant(
                  of: find.byType(TableScrollView),
                  matching: find.byType(Scrollbar),
                ),
              )
              .controller!;
          horizontal.jumpTo(horizontal.position.maxScrollExtent);
          final vertical = tester.state<ScrollableState>(
            find.descendant(
              of: find.byType(TableFullscreenPreview),
              matching: find.byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              ),
            ),
          );
          vertical.position.jumpTo(vertical.position.maxScrollExtent);
          await tester.pump();
          expect(find.text('Last cell').hitTestable(), findsOneWidget);
        } else {
          expect(find.text('No drawing to preview'), findsOneWidget);
        }
        await tester.tap(find.byTooltip('Close preview'));
        await tester.pumpAndSettle();
        expect(find.text('Preview $kind'), findsOneWidget);
        expect(component.output, before);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        component.dispose();
        theme.dispose();
        document.dispose();
      });
    }
  }
}
