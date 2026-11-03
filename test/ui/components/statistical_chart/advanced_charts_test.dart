import 'dart:convert';
import 'dart:io';

import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/business/page_content.dart';
import 'package:booklet/storage/booklet_file.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_snapshot.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/statistical_chart_component.dart';
import 'package:booklet/ui/components/statistical_chart/box_plot.dart';
import 'package:booklet/ui/components/statistical_chart/statistical_chart_document.dart';
import 'package:booklet/ui/components/statistical_chart/statistical_chart_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> comboJson() => {
  'datasetFormat': 'categorical',
  'graphType': 'combo',
  'title': 'Sales and target',
  'labels': ['Jan', 'Feb', 'Mar'],
  'values': [12, 18, 16],
  'metricName': 'Sales',
  'primaryStyle': 'column',
  'showIntervals': true,
  'lower': [10, 16, 14],
  'upper': [14, 20, 18],
  'series': [
    {
      'name': 'Target',
      'style': 'line',
      'values': [15, 15, 15],
      'lower': [14, 14, 14],
      'upper': [16, 16, 16],
    },
  ],
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('new charts round trip through page storage and copy/paste', (
    tester,
  ) async {
    for (final json in [
      comboJson(),
      {
        'graphType': 'boxPlot',
        'title': 'Groups',
        'labels': ['A', 'A', 'B'],
        'values': [1, 3, 6],
      },
    ]) {
      final component = StatisticalChartComponent(id: 'advanced-chart')
        ..state.restore(json);
      final copy = ComponentSnapshot.capture(ComponentBox(component: component))
          .instantiate();
      expect(
        (copy.component.state as StatisticalChartState).toJson(),
        component.state.toJson(),
      );
      final settings = DocumentSettingsController();
      final theme = PageSettingsController(settings);
      await tester.runAsync(() async {
        final directory = await Directory.systemTemp.createTemp(
          'advanced_chart_test',
        );
        try {
          await BookletFile.savePage(
            directory.path,
            PageContent(
              id: 'p',
              title: 'Advanced chart',
              components: [ComponentBox(component: component)],
            ),
          );
          final page = await BookletFile.loadPage(directory.path, 'p', theme);
          expect(
            (page.components.single.component.state as StatisticalChartState)
                .toJson(),
            component.state.toJson(),
          );
          page.components.single.component.dispose();
        } finally {
          await directory.delete(recursive: true);
        }
      });
      component.dispose();
      copy.component.dispose();
      theme.dispose();
      settings.dispose();
    }
  });

  test('inclusive quartiles, observed whiskers and outliers', () {
    final values = <double>[100, 5, 4, 3, 2, 1, 0];
    final b = summarizeBoxPlot(values);
    expect([b.q1, b.median, b.q3], [1.5, 3, 4.5]);
    expect([b.lowerWhisker, b.upperWhisker], [0, 5]);
    expect(b.outliers, [100]);
    expect(values.first, 100); // Input remains unchanged.
    final constant = summarizeBoxPlot([5, 5, 5]);
    expect(constant.outliers, isEmpty);
    expect(constant.lowerWhisker, 5);
    expect(summarizeBoxPlot([7]).median, 7);
    expect(() => summarizeBoxPlot([]), throwsFormatException);
    expect(() => summarizeBoxPlot([double.nan]), throwsFormatException);
  });

  test('empty interval charts remain valid after serialization', () {
    final state = StatisticalChartState()
      ..restore({
        'graphType': 'line',
        'title': 'Empty',
        'labels': <String>[],
        'values': <double>[],
        'showIntervals': true,
        'lower': <double>[],
        'upper': <double>[],
      });
    expect(
      () => StatisticalChartState.validateJson(state.toJson()),
      returnsNormally,
    );
  });

  test('combo styles and asymmetric bounds survive JSON round trips', () {
    final state = StatisticalChartState()..restore(comboJson());
    final copy = StatisticalChartState()
      ..restore(jsonDecode(jsonEncode(state.toJson())));
    expect(copy.toJson(), state.toJson());
    expect(copy.metrics.map((m) => m.style), ['column', 'line']);
    expect(copy.series.single.upper, [16, 16, 16]);
    expect(copy.supportsIntervals, isTrue);
  });

  test('invalid intervals and combo styles fail atomically', () {
    final state = StatisticalChartState()..restore(comboJson());
    final before = state.toJson();
    for (final edit in [
      {
        'lower': [20, 16, 14],
      },
      {
        'upper': [14, 20],
      },
      {
        'upper': [14, double.infinity, 18],
      },
      {'primaryStyle': 'line'},
      {'primaryStyle': 'area'},
      {'showIntervals': 'yes'},
    ]) {
      expect(
        () => state.restore({...comboJson(), ...edit}),
        throwsFormatException,
      );
      expect(state.toJson(), before);
    }
    final missing = comboJson()..remove('lower');
    expect(
      () => StatisticalChartState.validateJson(missing),
      throwsFormatException,
    );
  });

  test('box observations retain group membership and reject extra metrics', () {
    final json = {
      'graphType': 'boxPlot',
      'title': 'Groups',
      'labels': ['A', 'A', 'B', 'B', 'B'],
      'values': [1, 3, 4, 5, 9],
    };
    final state = StatisticalChartState()..restore(json);
    expect(state.category, ChartDataFormat.observations);
    final unlabeled = StatisticalChartState()
      ..restore({
        'graphType': 'boxPlot',
        'title': 'One group',
        'values': [1, 2, 3],
      });
    expect(unlabeled.labels, ['Group 1', 'Group 1', 'Group 1']);
    expect(state.labels, ['A', 'A', 'B', 'B', 'B']);
    final copy = StatisticalChartState()..restore(state.toJson());
    expect(copy.toJson(), state.toJson());
    expect(
      () => StatisticalChartState.validateJson({
        ...json,
        'series': [
          {
            'name': 'Other',
            'values': [1, 2, 3, 4, 5],
          },
        ],
      }),
      throwsFormatException,
    );
  });

  testWidgets(
    'combo raw data syncs styles and bounds to table and saves edits',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
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
      await tester.tap(find.text('Raw data'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('statistical-chart-raw-data')),
        jsonEncode(comboJson()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Data set'));
      await tester.pumpAndSettle();
      expect(find.text('Lower bound'), findsNWidgets(2));
      expect(find.byType(DropdownButton<String>), findsNWidgets(2));
      final lower = find.byWidgetPredicate(
        (w) => w is TextFormField && w.controller?.text == '10.0',
      );
      await tester.enterText(lower, '9');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Raw data'));
      await tester.pumpAndSettle();
      final raw = tester.widget<TextField>(
        find.byKey(const ValueKey('statistical-chart-raw-data')),
      );
      expect(jsonDecode(raw.controller!.text)['lower'], [9, 16, 14]);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(state.type, ChartType.combo);
      expect(state.lower.first, 9);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'box plot and interval renderers handle constant and negative values',
    (tester) async {
      for (final json in [
        {
          'graphType': 'boxPlot',
          'title': 'Groups',
          'labels': ['A', 'A', 'A', 'B', 'B'],
          'values': [-5, -5, -5, 2, 100],
        },
        comboJson(),
        {...comboJson(), 'graphType': 'line'},
        {...comboJson(), 'graphType': 'column'},
      ]) {
        final state = StatisticalChartState()..restore(json);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: StatisticalChartPreview(state: state)),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    },
  );
}
