import 'dart:io';

import 'package:booklet/storage/booklet_file.dart';
import 'package:booklet/business/page_content.dart';

import 'dart:convert';

import 'package:image/image.dart' as image;

import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_snapshot.dart';
import 'package:booklet/ui/components/drawing/drawing_document.dart';
import 'package:booklet/ui/components/drawing/drawing_editor.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/drawing_component.dart';
import 'package:booklet/ui/components/inbuilt_components/inbuilt_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'PNG and editable content survive saving and independent copy/paste',
    (tester) async {
      final component = DrawingComponent(id: 'source');
      final elements = [
        for (final tool in DrawingTool.values)
          DrawingElement(
            tool: tool,
            points: const [Offset(20, 20), Offset(200, 100)],
            text: 'Word art',
            fillColor: Colors.yellow,
            fontFamily: 'Bangers',
            shadow: true,
            brush: DrawingBrush.marker,
            color: Colors.purple,
            bold: true,
            italic: true,
            outlined: true,
            filled: true,
          ),
      ];
      final bytes = await tester.runAsync(
        () => DrawingPainter.render(elements, backgroundColor: Colors.teal),
      );
      expect(bytes!.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      final png = image.decodePng(bytes)!;
      expect(png.getPixel(1190, 790).g.toInt(), 150);
      component.state.save(elements, bytes, backgroundColor: Colors.teal);
      final json = jsonDecode(
        jsonEncode(
          ComponentSnapshot.capture(ComponentBox(component: component))
              .toJson(),
        ),
      );
      final copy = ComponentSnapshot.fromJson(
        Map<String, dynamic>.from(json as Map),
      ).instantiate();
      final copiedState = copy.component.state as DrawingComponentState;
      expect(copy.component.id, isNot(component.id));
      expect(copiedState.toJson(), component.state.toJson());
      expect(copiedState.output, startsWith('data:image/png;base64,'));
      await tester.runAsync(() async {
        final theme = PageSettingsController(DocumentSettingsController());
        final directory = await Directory.systemTemp.createTemp('drawing_test');
        try {
          final page = PageContent(
            id: 'page',
            title: 'Drawing',
            components: [ComponentBox(component: component)],
          );
          await BookletFile.savePage(directory.path, page);
          final restored = await BookletFile.loadPage(
            directory.path,
            'page',
            theme,
          );
          expect(
            (restored.components.single.component.state
                    as DrawingComponentState)
                .toJson(),
            component.state.toJson(),
          );
          restored.components.single.component.dispose();
        } finally {
          await directory.delete(recursive: true);
          theme.documentSettingsController.dispose();
          theme.dispose();
        }
      });

      copiedState.save([], bytes);
      expect(component.state.elements.length, DrawingTool.values.length);
      expect(
        InbuiltComponents.prepareCompoent('new', 'Drawing'),
        isA<DrawingComponent>(),
      );
      component.dispose();
      copy.component.dispose();
    },
  );

  testWidgets('page preview only exposes edit when selected and writable', (
    tester,
  ) async {
    final component = DrawingComponent(id: 'drawing');
    final document = DocumentSettingsController();
    final theme = PageSettingsController(document);
    var selected = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => component.buildUI(
              theme: theme,
              componentState: component.state,
              isSelected: selected,
              onSelect: () => setState(() => selected = true),
              onCreateBelow: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Edit drawing'), findsNothing);
    await tester.tap(find.text('Drawing — select to edit'));
    await tester.pump();
    expect(find.text('Edit drawing'), findsOneWidget);
    await tester.tap(find.text('Edit drawing'));
    await tester.pumpAndSettle();
    expect(find.byType(DrawingEditor), findsOneWidget);
    expect(find.text('Freehand'), findsOneWidget);
    expect(find.text('Shapes'), findsOneWidget);
    expect(find.text('Text'), findsOneWidget);
    expect(component.state.elements, isEmpty);
    await tester.tap(find.byTooltip('Close drawing'));
    await tester.pumpAndSettle();
    expect(find.byType(DrawingEditor), findsNothing);
    document.updateEditMode(DocumentEditMode.readOnly);
    // Rebuild the component as the page does when document settings change.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: component.buildUI(
            theme: theme,
            componentState: component.state,
            isSelected: true,
            onSelect: () {},
            onCreateBelow: () {},
          ),
        ),
      ),
    );
    expect(find.text('Edit drawing'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    theme.dispose();
    document.dispose();
    component.dispose();
  });

  testWidgets(
    'drawing draft supports undo redo and discard without changing original',
    (tester) async {
      final state = DrawingComponentState();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => DrawingEditor(state: state),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final canvas = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is DrawingPainter,
      );
      await tester.dragFrom(tester.getCenter(canvas), const Offset(70, 30));
      await tester.pump();
      DrawingPainter painter() =>
          tester.widget<CustomPaint>(canvas).painter! as DrawingPainter;
      expect(painter().elements, hasLength(1));
      expect(state.elements, isEmpty);
      await tester.tap(find.byTooltip('Undo'));
      await tester.pump();
      expect(painter().elements, isEmpty);
      await tester.tap(find.byTooltip('Redo'));
      await tester.pump();
      expect(painter().elements, hasLength(1));
      await tester.tap(find.byTooltip('Close drawing'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.byType(DrawingEditor), findsNothing);
      expect(state.elements, isEmpty);
      state.dispose();
    },
  );

  testWidgets('compact layout supports placing styled text', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = DrawingComponentState();
    await tester.pumpWidget(MaterialApp(home: DrawingEditor(state: state)));
    await tester.tap(find.text('Text'));
    await tester.pump();
    await tester.ensureVisible(find.text('Bold'));
    await tester.tap(find.text('Bold'));
    await tester.pump();
    final canvas = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is DrawingPainter,
    );
    await tester.tap(canvas);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    final element =
        (tester.widget<CustomPaint>(canvas).painter! as DrawingPainter)
            .elements
            .single;
    expect(element.text, 'Hello');
    expect(element.bold, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
  testWidgets('Save commits a PNG and returns to the page', (tester) async {
    final state = DrawingComponentState();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => DrawingEditor(state: state),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Canvas size'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1024 × 1024'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    final canvas = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is DrawingPainter,
    );
    await tester.dragFrom(tester.getCenter(canvas), const Offset(70, 30));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      for (var i = 0; i < 100 && state.preview == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect(state.elements, hasLength(1));
    expect(state.preview, isNotNull);
    expect(state.canvasSize, const Size(1024, 1024));
    final png = image.decodePng(state.preview!)!;
    expect(png.width, 1024);
    expect(png.height, 1024);
    expect(find.byType(DrawingEditor), findsNothing);
    state.dispose();
  });
}
