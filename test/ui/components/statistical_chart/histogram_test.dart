import 'dart:convert';
import 'dart:io';

import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/business/page_content.dart';
import 'package:booklet/storage/booklet_file.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_snapshot.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/statistical_chart_component.dart';
import 'package:booklet/ui/components/statistical_chart/histogram.dart';
import 'package:booklet/ui/components/statistical_chart/statistical_chart_document.dart';
import 'package:booklet/ui/components/statistical_chart/statistical_chart_editor.dart';
import 'package:booklet/ui/detail/editor/component_minimap_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> histogramJson() => {
  'graphType': 'histogram',
  'title': 'Scores',
  'values': [0, 1, 1, 2, 3, 4],
  'binCount': 2,
};
Finder valueField(String value) => find.byWidgetPredicate(
  (w) => w is TextFormField && w.controller?.text == value,
);
Future<void> tab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'equal-width bins count boundaries exactly once including the maximum',
    () {
      final bins = buildHistogram([0, 1, 1, 2, 3, 4], binCount: 2);
      expect(bins.map((b) => b.count), [3, 3]);
      expect(bins.first.lower, 0);
      expect(bins.first.upper, 2);
      expect(bins.first.includesUpper, isFalse);
      expect(bins.last.upper, 4);
      expect(bins.last.includesUpper, isTrue);
      final negative = buildHistogram([-4, -3, -2, -1, 0], binCount: 2);
      expect(negative.map((b) => b.count), [2, 3]);
      final decimal = buildHistogram([.1, .2, .3, .4], binCount: 3);
      expect(decimal.map((b) => b.count), [1, 1, 2]);
    },
  );
  test('empty, constant, tiny and very large datasets have valid bins', () {
    expect(buildHistogram([]), isEmpty);
    final constant = buildHistogram([5, 5, 5]);
    expect(constant.single.count, 3);
    final manual = buildHistogram([5, 5, 5], binCount: 4);
    expect(manual.length, 4);
    expect(manual.fold<int>(0, (a, b) => a + b.count), 3);
    for (final values in [
      [1e308, 1.1e308, 1.2e308],
      [1.7976931348623157e308, 1.7976931348623157e308],
      [1.0, 1.0000000000000002],
    ]) {
      final bins = buildHistogram(values, binCount: 100);
      expect(
        bins.every(
          (b) => b.lower.isFinite && b.upper.isFinite && b.upper > b.lower,
        ),
        isTrue,
      );
      expect(bins.fold<int>(0, (a, b) => a + b.count), values.length);
    }
    expect(() => buildHistogram([double.nan]), throwsFormatException);
    expect(() => buildHistogram([-1e308, 1e308]), throwsFormatException);
    expect(() => buildHistogram([1], binCount: 0), throwsFormatException);
  });
  test(
    'automatic binning preserves all observations and includes empty bins',
    () {
      final values = [for (var i = 0; i < 100; i++) (i % 10).toDouble()];
      final bins = buildHistogram(values);
      expect(bins.length, 8);
      expect(bins.fold<int>(0, (a, b) => a + b.count), 100);
      expect(buildHistogram([0, 10], binCount: 5).map((b) => b.count), [
        1,
        0,
        0,
        0,
        1,
      ]);
    },
  );
  test('histogram schema accepts observations without labels and rejects invalid settings', () {
    final state = StatisticalChartState()..restore(histogramJson());
    expect(state.type, ChartType.histogram);
    expect(state.category, ChartDataFormat.observations);
    expect(state.labels.length, 6);
    expect(state.histogramBinCount, 2);
    final saved = state.toJson();
    for (final invalid in [
      {
        ...saved,
        'values': [double.infinity],
      },
      {...saved, 'binCount': 0},
      {...saved, 'binCount': 101},
      {...saved, 'binCount': 2.5},
      {
        ...saved,
        'series': [
          {
            'name': 'Second',
            'values': [0, 1, 1, 2, 3, 4],
          },
        ],
      },
    ]) {
      expect(() => state.restore(invalid), throwsFormatException);
      expect(state.toJson(), saved);
    }
    state.dispose();
  });
  testWidgets('histograms round trip through page storage and copy/paste', (
    tester,
  ) async {
    final component = StatisticalChartComponent(id: 'histogram')
      ..state.restore(histogramJson());
    final copy = ComponentSnapshot.capture(ComponentBox(component: component))
        .instantiate();
    expect(
      (copy.component.state as StatisticalChartState).toJson(),
      component.state.toJson(),
    );
    final settings = DocumentSettingsController();
    final theme = PageSettingsController(settings);
    await tester.runAsync(() async {
      final directory = await Directory.systemTemp.createTemp('histogram_test');
      try {
        await BookletFile.savePage(
          directory.path,
          PageContent(
            id: 'p',
            title: 'Histogram',
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
  });
  testWidgets(
    'distribution selection keeps values and bin settings synchronize with raw JSON',
    (tester) async {
      final state = StatisticalChartState();
      await tester.pumpWidget(
        MaterialApp(home: StatisticalChartEditor(state: state)),
      );
      await tester.tap(find.byType(DropdownButtonFormField<ChartFamily>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ChartFamily.distributions.label).last);
      await tester.pumpAndSettle();
      var preview = tester.widget<StatisticalChartPreview>(
        find.byType(StatisticalChartPreview),
      );
      expect(preview.state.type, ChartType.histogram);
      expect(preview.state.values, [3, 7, 5]);
      await tab(tester, 'Data set');
      expect(find.text('Horizontal axis'), findsNothing);
      expect(find.text('Label'), findsNothing);
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2 bins'));
      await tester.pumpAndSettle();
      await tab(tester, 'Raw data');
      final rawField = find.byKey(const ValueKey('statistical-chart-raw-data'));
      var json = jsonDecode(
        tester.widget<TextField>(rawField).controller!.text,
      ) as Map<String, dynamic>;
      expect(json['binCount'], 2);
      await tester.enterText(
        rawField,
        jsonEncode({
          ...histogramJson(),
          'values': [1, 2, 2, 3],
          'binCount': 3,
        }),
      );
      await tab(tester, 'Data set');
      expect(valueField('2.0'), findsNWidgets(2));
      expect(
        tester
            .widget<DropdownButtonFormField<int>>(
              find.byType(DropdownButtonFormField<int>),
            )
            .initialValue,
        3,
      );
      await tab(tester, 'Preview');
      preview = tester.widget<StatisticalChartPreview>(
        find.byType(StatisticalChartPreview),
      );
      expect(preview.state.values, [1, 2, 2, 3]);
      expect(find.textContaining('4 observations'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
  testWidgets(
    'histogram conversion preserves data until incompatible extra columns are removed',
    (tester) async {
      final state = StatisticalChartState()
        ..series = [
          ChartSeries('Second', [2, 4, 8]),
        ];
      await tester.pumpWidget(
        MaterialApp(home: StatisticalChartEditor(state: state)),
      );
      Future<void> family(ChartFamily value) async {
        await tester.tap(find.byType(DropdownButtonFormField<ChartFamily>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(value.label).last);
        await tester.pumpAndSettle();
      }

      await family(ChartFamily.distributions);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
            .onPressed,
        isNull,
      );
      var preview = tester.widget<StatisticalChartPreview>(
        find.byType(StatisticalChartPreview),
      );
      expect(preview.state.metrics.length, 2);
      await tab(tester, 'Data set');
      final remove = find.byTooltip('Remove value column').last;
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      await tab(tester, 'Preview');
      preview = tester.widget<StatisticalChartPreview>(
        find.byType(StatisticalChartPreview),
      );
      expect(preview.state.type, ChartType.histogram);
      expect(preview.state.values, [3, 7, 5]);
      await family(ChartFamily.lineArea);
      preview = tester.widget<StatisticalChartPreview>(
        find.byType(StatisticalChartPreview),
      );
      expect(preview.state.labels, ['A', 'B', 'C']);
      expect(preview.state.values, [3, 7, 5]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
  testWidgets(
    'bulk paste adds original observations and invalid text never replaces data',
    (tester) async {
      final state = StatisticalChartState()
        ..restore({...histogramJson(), 'values': []});
      await tester.pumpWidget(
        MaterialApp(home: StatisticalChartEditor(state: state)),
      );
      await tab(tester, 'Data set');
      final paste = find.byKey(const ValueKey('histogram-paste-values'));
      await tester.enterText(paste, '-2, 0; 1\n1 4,');
      await tester.tap(find.text('Add values'));
      await tester.pumpAndSettle();
      await tab(tester, 'Preview');
      var preview = tester.widget<StatisticalChartPreview>(
        find.byType(StatisticalChartPreview),
      );
      expect(preview.state.values, [-2, 0, 1, 1, 4]);
      await tab(tester, 'Data set');
      await tester.enterText(paste, '3, invalid, 5');
      await tester.tap(find.text('Add values'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Enter finite numbers separated'),
        findsOneWidget,
      );
      await tab(tester, 'Preview');
      preview = tester.widget<StatisticalChartPreview>(
        find.byType(StatisticalChartPreview),
      );
      expect(preview.state.values, [-2, 0, 1, 1, 4]);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
  testWidgets('histogram thumbnails show the real plot at compressed sizes', (
    tester,
  ) async {
    final component = StatisticalChartComponent(id: 'mini')
      ..state.restore(histogramJson());
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
      final plot = tester.renderObject<RenderBox>(
        find.byType(StatisticalChartPreview),
      );
      final rect = MatrixUtils.transformRect(
        plot.getTransformTo(root),
        Offset.zero & plot.size,
      );
      expect(rect.bottom, lessThanOrEqualTo(height + .001));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    component.dispose();
  });
}
