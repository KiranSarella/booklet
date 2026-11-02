import 'package:booklet/ui/components/inbuilt_components/inbuilt_components.dart';
import 'package:booklet/ui/components/component_types.dart';

import 'dart:convert';
import 'dart:io';

import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/business/page_content.dart';
import 'package:booklet/storage/booklet_file.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_snapshot.dart';
import 'package:booklet/ui/components/statistical_chart/statistical_chart_document.dart';
import 'package:booklet/ui/components/statistical_chart/statistical_chart_editor.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/statistical_chart_component.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('component menu and old snapshots resolve to Statistical Chart', () {
    final menu = InbuiltComponents.getComponentMenuItems();
    expect(
      menu.where((c) => c.key == 'statistical_chart').single.name,
      'Statistical Chart',
    );
    expect(menu.any((c) => c.key == 'graph'), isFalse);
    expect(ComponentTypes.getTitleFor('graph'), 'Statistical Chart');
    expect(
      ComponentTypes.getIdForTitle('Statistical Chart'),
      'statistical_chart',
    );
    for (final key in [
      'graph',
      'Graph',
      'statistical_chart',
      'Statistical Chart',
    ]) {
      final component = InbuiltComponents.prepareCompoent('legacy', key);
      expect(component, isA<StatisticalChartComponent>());
      component.dispose();
    }
    final snapshot = ComponentSnapshot.fromJson({
      'type': 'graph',
      'extra': {
        'graphType': 'pie',
        'title': 'Old chart',
        'labels': ['A'],
        'values': [5],
      },
    }).instantiate();
    expect(snapshot.component.def.key, 'statistical_chart');
    expect(
      (snapshot.component.state as StatisticalChartState).title,
      'Old chart',
    );
    snapshot.component.dispose();
  });
  test('bubble areas track sizes without clipping or depending on units', () {
    final radii = bubbleMarkerRadii([1, 4, 16, 0], 4);
    expect(radii, [6, 12, 24, 0]);
    expect(radii[1] * radii[1] / (radii[0] * radii[0]), 4);
    expect(bubbleMarkerRadii([1e12, 4e12, 16e12, 0], 4), radii);
    expect(bubbleMarkerRadii([], 2), [24, 24]);
    expect(bubbleMarkerRadii([0, 0], 2), [0, 0]);
  });
  testWidgets('bubble Size edits survive switching to scatter and back', (
    tester,
  ) async {
    final state = StatisticalChartState()
      ..restore({
        'datasetFormat': 'xy',
        'graphType': 'bubble',
        'title': '',
        'xValues': [1, 2],
        'values': [5, 8],
        'sizes': [1, 1],
      });
    await tester.pumpWidget(
      MaterialApp(home: StatisticalChartEditor(state: state)),
    );
    expect(
      find.textContaining('All bubbles have the same Size'),
      findsOneWidget,
    );
    await tester.tap(find.text('Data set'));
    await tester.pumpAndSettle();
    final sizeField = find.bySemanticsLabel('Size').last;
    await tester.enterText(
      find.descendant(of: sizeField, matching: find.byType(TextFormField)),
      '9',
    );
    await tester.pump();
    Future<void> choose(ChartType type) async {
      await tester.tap(find.byType(DropdownButtonFormField<ChartType>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(type.label).last);
      await tester.pumpAndSettle();
    }

    await choose(ChartType.scatter);
    expect(find.text('Size'), findsNothing);
    await choose(ChartType.bubble);
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    final preview = tester.widget<StatisticalChartPreview>(
      find.byType(StatisticalChartPreview),
    );
    expect(preview.state.bubbleSizes, [1, 9]);
    expect(find.textContaining('All bubbles have the same Size'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
  testWidgets('graph survives document save and reload', (tester) async {
    final component = StatisticalChartComponent(id: 'stored');
    component.state.category = ChartDataFormat.grouped;
    component.state.type = ChartType.multiLine;
    component.state.series = [
      ChartSeries('Product B', [8, 4, 6]),
    ];
    component.state.title = 'Revenue';
    final document = DocumentSettingsController();
    final theme = PageSettingsController(document);
    await tester.runAsync(() async {
      final directory = await Directory.systemTemp.createTemp('graph_test');
      try {
        await BookletFile.savePage(
          directory.path,
          PageContent(
            id: 'p',
            title: 'Graph',
            components: [ComponentBox(component: component)],
          ),
        );
        final restored = await BookletFile.loadPage(directory.path, 'p', theme);
        expect(
          (restored.components.single.component.state as StatisticalChartState)
              .toJson(),
          component.state.toJson(),
        );
        restored.components.single.component.dispose();
        final pageFile = File('${directory.path}/pages/p.json');
        final saved =
            jsonDecode(await pageFile.readAsString()) as Map<String, dynamic>;
        expect(saved['components'][0]['type'], 'statistical_chart');
        saved['components'][0]['type'] = 'graph';
        await pageFile.writeAsString(jsonEncode(saved));
        final legacy = await BookletFile.loadPage(directory.path, 'p', theme);
        expect(legacy.components.single.component.def.key, 'statistical_chart');
        expect(
          (legacy.components.single.component.state as StatisticalChartState)
              .toJson(),
          component.state.toJson(),
        );
        legacy.components.single.component.dispose();
      } finally {
        await directory.delete(recursive: true);
      }
    });
    component.dispose();
    theme.dispose();
    document.dispose();
  });
  testWidgets('read-only pages offer preview without editing', (tester) async {
    final component = StatisticalChartComponent(id: 'readonly');
    final document = DocumentSettingsController()
      ..updateEditMode(DocumentEditMode.readOnly);
    final theme = PageSettingsController(document);
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
    expect(find.text('Edit chart'), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    await tester.tap(find.text('Preview chart'));
    await tester.pumpAndSettle();
    expect(find.byType(StatisticalChartFullscreenPreview), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    await tester.pumpWidget(const SizedBox());
    component.dispose();
    theme.dispose();
    document.dispose();
  });
  test('graph types round trip with labels and signed values', () {
    for (final type in ChartDataFormat.categorical.types) {
      final state = StatisticalChartState()
        ..type = type
        ..title = 'Sales'
        ..labels = ['One', 'Two']
        ..values = [-2, 5];
      final restored = StatisticalChartState()..restore(state.toJson());
      expect(restored.toJson(), state.toJson());
      restored.values[0] = 10;
      expect(state.values.first, -2);
      state.dispose();
      restored.dispose();
    }
  });
  test('invalid data cannot introduce non-finite values', () {
    final state = StatisticalChartState();
    state.restore({
      'graphType': 'unknown',
      'labels': ['A'],
      'values': [double.nan],
    });
    expect(state.type, ChartType.bar);
    expect(state.values, [3, 7, 5]);
    state.dispose();
  });
  test('graph snapshots preserve content independently', () {
    final component = StatisticalChartComponent(id: 'graph');
    component.state.title = 'Original';
    final snapshot = ComponentSnapshot.capture(
      ComponentBox(component: component),
    );
    component.state.title = 'Changed';
    final copy = snapshot.instantiate();
    expect(copy.component.state, isA<StatisticalChartState>());
    expect((copy.component.state as StatisticalChartState).title, 'Original');
    copy.component.dispose();
    component.dispose();
  });
  testWidgets('graph tabs synchronize JSON, table and preview', (tester) async {
    final state = StatisticalChartState();
    await tester.pumpWidget(
      MaterialApp(home: StatisticalChartEditor(state: state)),
    );
    expect(find.byType(StatisticalChartPreview), findsOneWidget);
    await tester.tap(find.text('Raw data'));
    await tester.pumpAndSettle();
    final rawFinder = find.byKey(const ValueKey('statistical-chart-raw-data'));
    await tester.enterText(
      rawFinder,
      jsonEncode({
        'graphType': 'line',
        'title': 'Updated',
        'labels': ['First', 'Second'],
        'values': [12, 24],
      }),
    );
    await tester.tap(find.text('Data set'));
    await tester.pumpAndSettle();
    expect(find.byType(Table), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'First'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'First'),
      'Changed',
    );
    await tester.enterText(find.widgetWithText(TextFormField, '12.0'), '42');
    await tester.tap(find.text('Add data point'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Raw data'));
    await tester.pumpAndSettle();
    Map<String, dynamic> json() =>
        jsonDecode(tester.widget<TextField>(rawFinder).controller!.text)
            as Map<String, dynamic>;
    expect(json()['labels'], ['Changed', 'Second', '']);
    expect(json()['values'], [42, 24, 0]);
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    final preview = tester.widget<StatisticalChartPreview>(
      find.byType(StatisticalChartPreview),
    );
    expect(preview.state.type, ChartType.line);
    expect(preview.state.values, [42, 24, 0]);
    expect(state.title, '');
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
  testWidgets('invalid raw input preserves last valid draft and blocks save', (
    tester,
  ) async {
    final state = StatisticalChartState();
    await tester.pumpWidget(
      MaterialApp(home: StatisticalChartEditor(state: state)),
    );
    await tester.tap(find.text('Raw data'));
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('statistical-chart-raw-data'));
    for (final invalid in [
      '{',
      '{"graphType":"bar","title":"Bad","labels":["A"],"values":[]}',
    ]) {
      await tester.enterText(field, invalid);
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.byType(StatisticalChartEditor), findsOneWidget);
      expect(tester.widget<TextField>(field).controller!.text, invalid);
      expect(state.title, '');
    }
    await tester.enterText(
      field,
      jsonEncode({
        'graphType': 'pie',
        'title': 'Fixed',
        'labels': [],
        'values': [],
      }),
    );
    await tester.tap(find.text('Data set'));
    await tester.pumpAndSettle();
    expect(find.byType(Table), findsOneWidget);
    expect(find.byTooltip('Remove data point'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
  test('dataset schemas round trip and legacy graphs remain categorical', () {
    for (final category in ChartDataFormat.values) {
      for (final type in category.types) {
        final state = StatisticalChartState()
          ..category = category
          ..type = type
          ..labels = category == ChartDataFormat.xy
              ? ['1', '9']
              : category == ChartDataFormat.timeSeries
              ? ['2026-01-01', '2026-04-01']
              : ['A', 'B']
          ..values = [2, 6]
          ..series = category == ChartDataFormat.grouped
              ? [
                  ChartSeries('Metric 2', [4, 8]),
                ]
              : [];
        final json = state.toJson();
        expect(json['datasetFormat'], category.name);
        expect(json.containsKey(category.dataKey), isTrue);
        final restored = StatisticalChartState()..restore(json);
        expect(restored.toJson(), json);
        state.dispose();
        restored.dispose();
      }
    }
    final legacy = StatisticalChartState()
      ..restore({
        'graphType': 'pie',
        'title': 'Old',
        'labels': ['A'],
        'values': [10],
      });
    expect(legacy.category, ChartDataFormat.categorical);
    expect(legacy.type, ChartType.pie);
    expect(legacy.labels, ['A']);
    expect(ChartDataFormat.validDate('2026-02-30'), isFalse);
    legacy.dispose();
  });
  testWidgets('chart families filter styles without replacing the dataset', (
    tester,
  ) async {
    final state = StatisticalChartState();
    await tester.pumpWidget(
      MaterialApp(home: StatisticalChartEditor(state: state)),
    );
    Future<void> choose(ChartFamily group) async {
      await tester.tap(find.byType(DropdownButtonFormField<ChartFamily>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(group.label).last);
      await tester.pumpAndSettle();
    }

    await choose(ChartFamily.lineArea);
    var dropdown = tester.widget<DropdownButtonFormField<ChartType>>(
      find.byType(DropdownButtonFormField<ChartType>),
    );
    expect(dropdown.initialValue, ChartType.line);
    await tester.tap(find.byType(DropdownButtonFormField<ChartType>));
    await tester.pumpAndSettle();
    expect(find.text('Pie'), findsNothing);
    await tester.tap(find.text('Area').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<StatisticalChartPreview>(find.byType(StatisticalChartPreview))
          .state
          .values,
      [3, 7, 5],
    );
    await choose(ChartFamily.partsWhole);
    expect(
      tester
          .widget<StatisticalChartPreview>(find.byType(StatisticalChartPreview))
          .state
          .labels,
      ['A', 'B', 'C'],
    );
    await choose(ChartFamily.barColumn);
    expect(
      tester
          .widget<StatisticalChartPreview>(find.byType(StatisticalChartPreview))
          .state
          .type,
      ChartType.column,
    );
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
  testWidgets(
    'numeric axis conversion preserves entered labels until corrected',
    (tester) async {
      final state = StatisticalChartState();
      await tester.pumpWidget(
        MaterialApp(home: StatisticalChartEditor(state: state)),
      );
      await tester.tap(find.byType(DropdownButtonFormField<ChartFamily>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ChartFamily.scatterBubble.label).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<StatisticalChartPreview>(
              find.byType(StatisticalChartPreview),
            )
            .state
            .labels,
        ['A', 'B', 'C'],
      );
      await tester.tap(find.text('Data set'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.enterText(
          find.byWidgetPredicate(
            (w) =>
                w is TextFormField && w.controller?.text == ['A', 'B', 'C'][i],
          ),
          '${i + 1}',
        );
      }
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      final preview = tester.widget<StatisticalChartPreview>(
        find.byType(StatisticalChartPreview),
      );
      expect(preview.state.type, ChartType.scatter);
      expect(preview.state.values, [3, 7, 5]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
  testWidgets('date axis stays independent of chart family and style', (
    tester,
  ) async {
    final state = StatisticalChartState()
      ..restore({
        'datasetFormat': 'timeSeries',
        'graphType': 'line',
        'title': 'Revenue',
        'dates': ['2026-01-01', '2026-03-01'],
        'values': [10, 20],
      });
    await tester.pumpWidget(
      MaterialApp(home: StatisticalChartEditor(state: state)),
    );
    await tester.tap(find.byType(DropdownButtonFormField<ChartFamily>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ChartFamily.barColumn.label).last);
    await tester.pumpAndSettle();
    final preview = tester.widget<StatisticalChartPreview>(
      find.byType(StatisticalChartPreview),
    );
    expect(preview.state.type, ChartType.column);
    expect(preview.state.category, ChartDataFormat.timeSeries);
    expect(preview.state.labels, ['2026-01-01', '2026-03-01']);
    await tester.tap(find.text('Data set'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButtonFormField<ChartDataFormat>>(
            find.byType(DropdownButtonFormField<ChartDataFormat>),
          )
          .initialValue,
      ChartDataFormat.timeSeries,
    );
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
  testWidgets(
    'raw edits synchronize chart family and reject invalid axis types',
    (tester) async {
      final state = StatisticalChartState();
      await tester.pumpWidget(
        MaterialApp(home: StatisticalChartEditor(state: state)),
      );
      await tester.tap(find.text('Raw data'));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('statistical-chart-raw-data'));
      final json = {
        'datasetFormat': 'xy',
        'graphType': 'scatter',
        'title': 'Points',
        'xValues': [1, 10],
        'values': [2, 3],
      };
      await tester.enterText(field, jsonEncode(json));
      await tester.pump();
      expect(
        tester
            .widget<DropdownButtonFormField<ChartFamily>>(
              find.byType(DropdownButtonFormField<ChartFamily>),
            )
            .initialValue,
        ChartFamily.scatterBubble,
      );
      await tester.enterText(
        field,
        jsonEncode({
          ...json,
          'datasetFormat': 'categorical',
          'labels': ['A', 'B'],
        }),
      );
      await tester.pump();
      expect(
        find.textContaining('Choose a compatible graphType'),
        findsOneWidget,
      );
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<StatisticalChartPreview>(
              find.byType(StatisticalChartPreview),
            )
            .state
            .type,
        ChartType.scatter,
      );
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
  testWidgets('all category and graph combinations render', (tester) async {
    for (final category in ChartDataFormat.values) {
      for (final type in category.types) {
        final state = StatisticalChartState()
          ..restore({
            'datasetFormat': category.name,
            'graphType': type.name,
            'title': type.label,
            category.dataKey: category == ChartDataFormat.xy
                ? [9, 1, 5]
                : category == ChartDataFormat.timeSeries
                ? ['2026-03-01', '2026-01-01', '2026-02-01']
                : ['A', 'B', 'C'],
            'values': [2, 5, 3],
            if (category.supportsSeries)
              'series': [
                {
                  'name': 'Second',
                  'values': [4, -2, 1],
                },
              ],
            if (category == ChartDataFormat.xy) 'sizes': [1, 9, 4],
          });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: StatisticalChartPreview(state: state)),
          ),
        );
        expect(
          tester.takeException(),
          isNull,
          reason: '${category.name}/${type.name}',
        );
        await tester.pumpWidget(const SizedBox());
        state.dispose();
      }
    }
  });
  test('multi-series validation and composition constraints', () {
    final grouped = {
      'datasetFormat': 'grouped',
      'graphType': 'stackedBar',
      'title': '',
      'labels': ['A', 'B'],
      'values': [2, 3],
      'metricName': 'First',
      'series': [
        {
          'name': 'Second',
          'values': [4, -1],
        },
      ],
    };
    expect(() => StatisticalChartState.validateJson(grouped), returnsNormally);
    expect(
      () => StatisticalChartState.validateJson({...grouped, 'series': []}),
      throwsFormatException,
    );
    expect(
      () => StatisticalChartState.validateJson({
        ...grouped,
        'series': [
          {
            'name': 'Second',
            'values': [1],
          },
        ],
      }),
      throwsFormatException,
    );
    final composition = {
      'datasetFormat': 'composition',
      'graphType': 'stacked100',
      'title': '',
      'labels': ['A', 'B'],
      'values': [20, 80],
    };
    expect(
      () => StatisticalChartState.validateJson(composition),
      returnsNormally,
    );
    expect(
      () => StatisticalChartState.validateJson({
        ...composition,
        'values': [-1, 80],
      }),
      throwsFormatException,
    );
    expect(
      () => StatisticalChartState.validateJson({
        ...composition,
        'values': [0, 0],
      }),
      throwsFormatException,
    );
  });
  testWidgets('grouped metrics synchronize table and JSON in both directions', (
    tester,
  ) async {
    final state = StatisticalChartState();
    await tester.pumpWidget(
      MaterialApp(home: StatisticalChartEditor(state: state)),
    );
    await tester.tap(find.text('Data set'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add value column'));
    await tester.tap(find.text('Add value column'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byWidgetPredicate(
        (w) => w is TextFormField && w.controller?.text == 'Metric 2',
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) => w is TextFormField && w.controller?.text == 'Metric 2',
      ),
      findsOneWidget,
    );
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextFormField && w.controller?.text == 'Metric 2',
      ),
      'Revenue',
    );
    await tester.ensureVisible(find.text('Add value column'));
    await tester.tap(find.text('Add value column'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Raw data'));
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('statistical-chart-raw-data'));
    final json = jsonDecode(
      tester.widget<TextField>(field).controller!.text,
    ) as Map<String, dynamic>;
    expect((json['series'] as List).length, 2);
    expect(json['series'][0]['name'], 'Revenue');
    json['series'][0]['values'] = [11, 22, 33];
    await tester.enterText(field, jsonEncode(json));
    await tester.tap(find.text('Data set'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, '11.0'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Remove value column').last);
    await tester.tap(find.byTooltip('Remove value column').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    final preview = tester.widget<StatisticalChartPreview>(
      find.byType(StatisticalChartPreview),
    );
    expect(preview.state.metrics.length, 2);
    expect(preview.state.series.single.values, [11, 22, 33]);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
  testWidgets('editor saves explicitly and back discards draft', (
    tester,
  ) async {
    final state = StatisticalChartState();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => StatisticalChartEditor(state: state),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Discarded');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(state.title, '');
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Saved');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(state.title, 'Saved');
    state.dispose();
  });
}
