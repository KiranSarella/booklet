import 'package:booklet/ui/components/drawing/drawing_document.dart';
import 'package:booklet/ui/components/drawing/drawing_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'legacy drawings retain their colors and default to white backgrounds',
    () {
      final state = DrawingComponentState();
      state.restore({
        'elements': [
          {
            'tool': 'rectangle',
            'points': [
              [10, 10],
              [100, 100],
            ],
            'color': Colors.red.toARGB32(),
            'width': 4,
            'filled': true,
          },
        ],
      });
      expect(state.backgroundColor, Colors.white);
      expect(state.elements.single.fillColor.toARGB32(), Colors.red.toARGB32());
      expect(state.elements.single.brush, DrawingBrush.pencil);
      state.dispose();
    },
  );

  test('transforms preserve styles and hit tests follow geometry', () {
    final original = DrawingElement(
      tool: DrawingTool.rectangle,
      points: const [Offset(10, 20), Offset(110, 70)],
      color: Colors.red,
      fillColor: Colors.green,
      filled: true,
    );
    final transformed = original.translated(const Offset(20, 30)).resized(2, 3);
    expect(transformed.bounds, const Rect.fromLTWH(30, 50, 200, 150));
    expect(transformed.fillColor, Colors.green);
    expect(original.bounds, const Rect.fromLTWH(10, 20, 100, 50));
    expect(transformed.hitTest(const Offset(100, 100), 2), isTrue);
    final line = DrawingElement(
      tool: DrawingTool.line,
      points: const [Offset(0, 0), Offset(100, 100)],
    );
    expect(line.hitTest(const Offset(50, 50), 3), isTrue);
    expect(line.hitTest(const Offset(10, 90), 3), isFalse);
  });

  test('new styles and background survive JSON restoration', () {
    final state = DrawingComponentState();
    final element = DrawingElement(
      tool: DrawingTool.text,
      points: const [Offset(10, 10)],
      text: 'Word art',
      fontFamily: 'Bangers',
      fontSize: 80,
      shadow: true,
      outlined: true,
      fillColor: Colors.yellow,
      color: Colors.red,
      brush: DrawingBrush.marker,
    );
    state.restore({
      'elements': [element.toJson()],
      'backgroundColor': Colors.teal.toARGB32(),
    });
    final restored = DrawingComponentState()..restore(state.toJson());
    expect(restored.toJson(), state.toJson());
    expect(restored.elements.single.shadow, isTrue);
    expect(restored.backgroundColor.toARGB32(), Colors.teal.toARGB32());
    restored.dispose();
    state.dispose();
  });

  Finder canvas() => find.byWidgetPredicate(
    (w) => w is CustomPaint && w.painter is DrawingPainter,
  );
  DrawingPainter painter(WidgetTester tester) =>
      tester.widget<CustomPaint>(canvas()).painter! as DrawingPainter;
  Offset screen(WidgetTester tester, Offset point) {
    final rect = tester.getRect(canvas());
    return rect.topLeft +
        Offset(
          point.dx * rect.width / painter(tester).documentSize.width,
          point.dy * rect.height / painter(tester).documentSize.height,
        );
  }

  Future<void> color(WidgetTester tester, String label, Color value) async {
    final target = label == 'Background'
        ? find.byTooltip(label)
        : find.text(label);
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
    tester.widget<ColorPicker>(find.byType(ColorPicker)).onColorChanged(value);
    await tester.tap(find.text('Use color'));
    await tester.pumpAndSettle();
  }

  testWidgets('select move resize recolor delete and undo an existing shape', (
    tester,
  ) async {
    final state = DrawingComponentState()
      ..restore({
        'elements': [
          DrawingElement(
            tool: DrawingTool.rectangle,
            points: const [Offset(400, 250), Offset(650, 500)],
            filled: true,
          ).toJson(),
        ],
      });
    await tester.pumpWidget(MaterialApp(home: DrawingEditor(state: state)));
    await tester.tap(find.text('Select'));
    await tester.pump();
    await tester.tapAt(screen(tester, const Offset(500, 350)));
    await tester.pump();
    expect(painter(tester).selectedIndex, 0);
    await tester.dragFrom(
      screen(tester, const Offset(500, 350)),
      const Offset(40, 20),
    );
    await tester.pump();
    final moved = painter(tester).elements.single.bounds;
    expect(moved.left, greaterThan(400));
    await tester.dragFrom(
      screen(tester, moved.inflate(8).bottomRight),
      const Offset(35, 35),
    );
    await tester.pump();
    expect(
      painter(tester).elements.single.bounds.width,
      greaterThan(moved.width),
    );
    await color(tester, 'Stroke', Colors.red);
    await color(tester, 'Fill color', Colors.yellow);
    expect(painter(tester).elements.single.color, Colors.red);
    expect(painter(tester).elements.single.fillColor, Colors.yellow);
    await tester.ensureVisible(find.byTooltip('Delete selected'));
    await tester.tap(find.byTooltip('Delete selected'));
    await tester.pump();
    expect(painter(tester).elements, isEmpty);
    await tester.tap(find.byTooltip('Undo'));
    await tester.pump();
    expect(painter(tester).elements, hasLength(1));
    // Draft edits have not touched the saved source.
    expect(state.elements.single.bounds.left, 400);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });

  testWidgets('selected text can be rewritten and given word art styles', (
    tester,
  ) async {
    final state = DrawingComponentState()
      ..restore({
        'elements': [
          DrawingElement(
            tool: DrawingTool.text,
            points: const [Offset(300, 300)],
            text: 'Before',
          ).toJson(),
        ],
      });
    await tester.pumpWidget(MaterialApp(home: DrawingEditor(state: state)));
    await tester.tap(find.text('Select'));
    await tester.pump();
    await tester.tapAt(screen(tester, const Offset(310, 310)));
    await tester.pump();
    await tester.ensureVisible(find.text('Edit text'));
    await tester.tap(find.text('Edit text'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'After');
    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Shadow'));
    await tester.tap(find.text('Shadow'));
    await tester.pump();
    await tester.tap(find.text('Outline'));
    await tester.pump();
    expect(painter(tester).elements.single.text, 'After');
    expect(painter(tester).elements.single.shadow, isTrue);
    expect(painter(tester).elements.single.outlined, isTrue);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });

  testWidgets('canvas background change is undoable', (tester) async {
    final state = DrawingComponentState();
    await tester.pumpWidget(MaterialApp(home: DrawingEditor(state: state)));
    await color(tester, 'Background', Colors.orange);
    expect(painter(tester).backgroundColor, Colors.orange);
    await tester.tap(find.byTooltip('Undo'));
    await tester.pump();
    expect(painter(tester).backgroundColor, Colors.white);
    await tester.tap(find.byTooltip('Redo'));
    await tester.pump();
    expect(painter(tester).backgroundColor, Colors.orange);
    expect(state.backgroundColor, Colors.white);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
  testWidgets(
    'zoom controls and canvas size validation preserve document coordinates',
    (tester) async {
      final state = DrawingComponentState();
      await tester.pumpWidget(MaterialApp(home: DrawingEditor(state: state)));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byTooltip('Undo')).dy, lessThan(60));
      expect(
        tester.getTopLeft(find.byTooltip('Background')).dx,
        lessThan(tester.getTopLeft(find.text('Save')).dx),
      );
      await tester.tap(find.text('Canvas size'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Width (px)'),
        '0',
      );
      await tester.tap(find.text('Apply'));
      await tester.pump();
      expect(find.text('Enter 64–4096 pixels'), findsOneWidget);
      await tester.tap(find.text('800 × 600'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(painter(tester).documentSize, const Size(800, 600));
      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();
      expect(painter(tester).documentSize, const Size(1200, 800));
      await tester.tap(find.byTooltip('Redo'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Actual size'));
      await tester.pumpAndSettle();
      expect(find.text('100%'), findsOneWidget);
      await tester.tap(find.byTooltip('Zoom in'));
      await tester.pumpAndSettle();
      expect(find.text('125%'), findsOneWidget);
      await tester.tap(find.byTooltip('Zoom out'));
      await tester.pumpAndSettle();
      expect(find.text('100%'), findsOneWidget);
      await tester.tap(find.byTooltip('Fit canvas'));
      await tester.pumpAndSettle();
      await tester.tapAt(screen(tester, const Offset(400, 300)));
      await tester.pump();
      expect(
        painter(tester).elements.single.points.single.dx,
        closeTo(400, .1),
      );
      expect(
        painter(tester).elements.single.points.single.dy,
        closeTo(300, .1),
      );
      expect(find.text('Canvas size'), findsNothing);
      expect(state.elements, isEmpty);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
}
