import 'dart:convert';
import 'dart:io';

import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/business/page_content.dart';
import 'package:booklet/storage/booklet_file.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_snapshot.dart';
import 'package:booklet/ui/components/component_types.dart';
import 'package:booklet/ui/components/inbuilt_components/inbuilt_components.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/math_graph_component.dart';
import 'package:booklet/ui/components/math_graph/math_graph_document.dart';
import 'package:booklet/ui/components/math_graph/math_graph_editor.dart';
import 'package:booklet/ui/detail/editor/component_minimap_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'menu, factory, document and snapshots preserve equations independently',
    () {
      expect(
        InbuiltComponents.getComponentMenuItems()
            .where((d) => d.key == 'math_graph')
            .single
            .name,
        'Math Graph',
      );
      expect(ComponentTypes.getIdForTitle('Math Graph'), 'math_graph');
      final component = InbuiltComponents.prepareCompoent('math', 'Math Graph');
      expect(component, isA<MathGraphComponent>());
      final state = component.state as MathGraphState;
      state.restore({
        ...state.toJson(),
        'title': 'Waves',
        'angleUnit': 'degrees',
        'equations': [
          {'expression': 'sin(x)'},
          {'expression': '2x+1', 'visible': false},
        ],
      });
      final snapshot = ComponentSnapshot.capture(
        ComponentBox(component: component),
      );
      final copy = ComponentSnapshot.fromJson(snapshot.toJson()).instantiate();
      expect((copy.component.state as MathGraphState).toJson(), state.toJson());
      state.restore({...state.toJson(), 'title': 'Changed'});
      expect((copy.component.state as MathGraphState).document.title, 'Waves');
      component.dispose();
      copy.component.dispose();
    },
  );
  test('invalid document updates leave the previous graph intact', () {
    final state = MathGraphState();
    final original = state.toJson();
    for (final invalid in [
      {...original, 'xMin': 10, 'xMax': 1},
      {...original, 'yMax': double.infinity},
      {...original, 'equations': []},
      {
        ...original,
        'equations': [
          {'expression': 'x+'},
        ],
      },
      {...original, 'angleUnit': 'unknown'},
    ]) {
      expect(() => state.restore(invalid), throwsFormatException);
      expect(state.toJson(), original);
    }
    state.dispose();
  });
  test('sampling splits reciprocal poles and clips logarithm domains', () {
    final reciprocal = MathGraphDocument.fromJson({
      'xMin': -2,
      'xMax': 2,
      'yMin': -10,
      'yMax': 10,
      'equations': [
        {'expression': '1/x'},
      ],
    });
    final segments = sampleMathGraph(reciprocal.equations.single, reciprocal);
    expect(segments.length, greaterThanOrEqualTo(2));
    expect(
      segments.every(
        (s) => s.every((p) => p.dx < 0) || s.every((p) => p.dx > 0),
      ),
      isTrue,
    );
    final log = MathGraphDocument.fromJson({
      'equations': [
        {'expression': 'ln(x)'},
      ],
    });
    expect(
      sampleMathGraph(
        log.equations.single,
        log,
      ).expand((s) => s).every((p) => p.dx > 0 && p.dy.isFinite),
      isTrue,
    );
    final hidden = MathGraphEquation('x', visible: false);
    expect(sampleMathGraph(hidden, log), isEmpty);
  });
  testWidgets('math graphs round trip through page storage', (tester) async {
    final component = MathGraphComponent(id: 'stored');
    component.state.restore({
      ...component.state.toJson(),
      'equations': [
        {'expression': 'cos(x)'},
        {'expression': 'x^3'},
      ],
      'title': 'Functions',
    });
    final settings = DocumentSettingsController();
    final theme = PageSettingsController(settings);
    await tester.runAsync(() async {
      final directory = await Directory.systemTemp.createTemp(
        'math_graph_test',
      );
      try {
        await BookletFile.savePage(
          directory.path,
          PageContent(
            id: 'p',
            title: 'Graphs',
            components: [ComponentBox(component: component)],
          ),
        );
        final page = await BookletFile.loadPage(directory.path, 'p', theme);
        expect(page.components.single.component.def.key, 'math_graph');
        expect(
          (page.components.single.component.state as MathGraphState).toJson(),
          component.state.toJson(),
        );
        page.components.single.component.dispose();
      } finally {
        await directory.delete(recursive: true);
      }
    });
    component.dispose();
    theme.dispose();
    settings.dispose();
  });
  testWidgets('page and full-screen preview are read-only', (tester) async {
    final component = MathGraphComponent(id: 'readonly');
    final settings = DocumentSettingsController()
      ..updateEditMode(DocumentEditMode.readOnly);
    final theme = PageSettingsController(settings);
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
    expect(find.text('Edit graph'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Preview graph'));
    await tester.pumpAndSettle();
    expect(find.byType(MathGraphFullscreenPreview), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    component.dispose();
    theme.dispose();
    settings.dispose();
  });
  testWidgets(
    'equations and raw JSON synchronize and invalid edits preserve preview',
    (tester) async {
      final state = MathGraphState();
      await tester.pumpWidget(MaterialApp(home: MathGraphEditor(state: state)));
      await tester.tap(find.text('Equations'));
      await tester.pumpAndSettle();
      final expression = find.byWidgetPredicate(
        (w) => w is TextFormField && w.controller?.text == 'x^2',
      );
      await tester.ensureVisible(expression);
      await tester.enterText(expression, 'sin(x)');
      await tester.tap(find.text('Raw data'));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('math-graph-raw-data'));
      final json = jsonDecode(
        tester.widget<TextField>(field).controller!.text,
      ) as Map<String, dynamic>;
      expect(json['equations'][0]['expression'], 'sin(x)');
      await tester.enterText(
        field,
        jsonEncode({
          ...json,
          'title': 'Updated',
          'angleUnit': 'degrees',
          'xMax': 360,
          'equations': [
            {'expression': 'cos(x)'},
            {'expression': '2x', 'visible': false},
          ],
        }),
      );
      await tester.tap(find.text('Equations'));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) => w is TextFormField && w.controller?.text == 'cos(x)',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      var preview = tester.widget<MathGraphPreview>(
        find.byType(MathGraphPreview),
      );
      expect(preview.state.document.title, 'Updated');
      expect(preview.state.document.degrees, isTrue);
      expect(state.document.title, '');
      await tester.tap(find.text('Raw data'));
      await tester.pumpAndSettle();
      await tester.enterText(field, '{');
      await tester.pump();
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      preview = tester.widget<MathGraphPreview>(find.byType(MathGraphPreview));
      expect(preview.state.document.title, 'Updated');
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
  testWidgets(
    'starters, visibility and removal update the same equations draft',
    (tester) async {
      final state = MathGraphState();
      await tester.pumpWidget(MaterialApp(home: MathGraphEditor(state: state)));
      await tester.tap(find.text('Equations'));
      await tester.pumpAndSettle();
      final starter = find.byType(DropdownButtonFormField<MathGraphTemplate>);
      await tester.ensureVisible(starter);
      await tester.tap(starter);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Linear: 2*x + 1').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add equation'));
      await tester.tap(find.text('Add equation'));
      await tester.pumpAndSettle();
      final checkbox = find.byType(Checkbox).at(1);
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      var document = tester
          .widget<MathGraphPreview>(find.byType(MathGraphPreview))
          .state
          .document;
      expect(document.equations.length, 2);
      expect(document.equations.last.expression, '2*x + 1');
      expect(document.equations.last.visible, isFalse);
      await tester.tap(find.text('Equations'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Remove equation').last);
      await tester.tap(find.byTooltip('Remove equation').last);
      await tester.pumpAndSettle();
      final max = find.byKey(const ValueKey('math-graph-xMax'));
      await tester.ensureVisible(max);
      await tester.enterText(max, '-20');
      await tester.pump();
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
            .onPressed,
        isNull,
      );
      await tester.enterText(max, '20');
      await tester.pump();
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      document = tester
          .widget<MathGraphPreview>(find.byType(MathGraphPreview))
          .state
          .document;
      expect(document.equations.length, 1);
      expect(document.xMax, 20);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
  testWidgets(
    'raw equation count changes safely across repeated tab switches',
    (tester) async {
      final state = MathGraphState();
      await tester.pumpWidget(MaterialApp(home: MathGraphEditor(state: state)));
      for (final count in [3, 1, 2]) {
        await tester.tap(find.text('Raw data'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('math-graph-raw-data')),
          jsonEncode({
            ...state.toJson(),
            'equations': List.generate(count, (i) => {'expression': 'x + $i'}),
          }),
        );
        await tester.tap(find.text('Equations'));
        await tester.pumpAndSettle();
        expect(find.byType(Checkbox), findsNWidgets(count));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
  testWidgets('editor saves explicitly and closing discards changes', (
    tester,
  ) async {
    final state = MathGraphState();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MathGraphEditor(state: state),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Equations'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('math-graph-title')),
      'Discarded',
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(state.document.title, '');
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Equations'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('math-graph-title')),
      'Saved',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(state.document.title, 'Saved');
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
  testWidgets(
    'all starters render and minimaps fit compressed rows and update',
    (tester) async {
      final component = MathGraphComponent(id: 'mini');
      for (final starter in MathGraphTemplate.values) {
        component.state.restore({
          ...component.state.toJson(),
          'equations': [
            {'expression': starter.expression},
          ],
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: MathGraphPreview(state: component.state)),
          ),
        );
        expect(tester.takeException(), isNull, reason: starter.name);
      }
      final box = ComponentBox(component: component);
      for (final height in [3.0, 30.0, 80.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: 150,
                height: height,
                child: ComponentMinimapPreview(box: box),
              ),
            ),
          ),
        );
        final root = tester.renderObject<RenderBox>(
          find.byType(ComponentMinimapPreview),
        );
        final chart = tester.renderObject<RenderBox>(
          find.byType(MathGraphPreview),
        );
        final rect = MatrixUtils.transformRect(
          chart.getTransformTo(root),
          Offset.zero & chart.size,
        );
        expect(rect.top, greaterThanOrEqualTo(-.001));
        expect(rect.bottom, lessThanOrEqualTo(height + .001));
        expect(tester.takeException(), isNull);
      }
      component.state.restore({
        ...component.state.toJson(),
        'title': 'Updated miniature',
      });
      await tester.pump();
      expect(find.text('Updated miniature'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      component.dispose();
    },
  );
}
