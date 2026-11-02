import 'dart:convert';
import 'dart:io';

import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/business/page_content.dart';
import 'package:booklet/storage/booklet_file.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_snapshot.dart';
import 'package:booklet/ui/components/component_types.dart';
import 'package:booklet/ui/components/gantt_chart/gantt_chart_document.dart';
import 'package:booklet/ui/components/gantt_chart/gantt_chart_editor.dart';
import 'package:booklet/ui/components/inbuilt_components/inbuilt_components.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/gantt_chart_component.dart';
import 'package:booklet/ui/detail/editor/component_minimap_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> fixture() => {
  'title': 'Book project',
  'timelineScale': 'auto',
  'tasks': [
    {
      'id': 'plan',
      'title': 'Plan',
      'start': '2026-11-02',
      'end': '2026-11-03',
      'progress': 100,
    },
    {
      'id': 'write',
      'title': 'Write',
      'start': '2026-11-04',
      'end': '2026-11-08',
      'progress': 40,
      'dependencies': ['plan'],
    },
    {
      'id': 'review',
      'title': 'Review',
      'start': '2026-11-09',
      'end': '2026-11-11',
      'progress': 0,
      'dependencies': ['write'],
    },
  ],
};
Map<String, dynamic> trackingFixture() {
  final json = fixture();
  json['chartType'] = 'tracking';
  json['tasks'] = (json['tasks'] as List)
      .map(
        (t) => {
          ...t as Map,
          'baselineStart': ganttDate(
            parseGanttDate(t['start']).subtract(const Duration(days: 2)),
          ),
          'baselineEnd': ganttDate(
            parseGanttDate(t['end']).add(const Duration(days: 2)),
          ),
        },
      )
      .toList();
  return json;
}

Finder taskCell(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == label,
  ),
  matching: find.byType(TextFormField),
);
Future<void> chooseType(WidgetTester tester, GanttChartType type) async {
  await tester.tap(find.byType(DropdownButtonFormField<GanttChartType>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(type.label).last);
  await tester.pumpAndSettle();
}

Finder input(String value) => find.byWidgetPredicate(
  (w) => w is TextFormField && w.controller?.text == value,
);
Future<void> tab(WidgetTester tester, String name) async {
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'Gantt registration and snapshots preserve stable IDs independently',
    () {
      expect(
        InbuiltComponents.getComponentMenuItems()
            .where((d) => d.key == 'gantt_chart')
            .single
            .name,
        'Gantt Chart',
      );
      expect(ComponentTypes.getIdForTitle('Gantt Chart'), 'gantt_chart');
      final component = InbuiltComponents.prepareCompoent(
        'gantt',
        'Gantt Chart',
      );
      expect(component, isA<GanttChartComponent>());
      final state = component.state as GanttChartState;
      state.restore(fixture());
      final copy = ComponentSnapshot.fromJson(
        ComponentSnapshot.capture(ComponentBox(component: component)).toJson(),
      ).instantiate();
      expect(
        (copy.component.state as GanttChartState).toJson(),
        state.toJson(),
      );
      state.restore({...fixture(), 'title': 'Changed'});
      expect(
        (copy.component.state as GanttChartState).document.title,
        'Book project',
      );
      component.dispose();
      copy.component.dispose();
    },
  );
  test(
    'calendar dates, inclusive durations and ranges are timezone independent',
    () {
      final document = GanttDocument.fromJson(fixture());
      expect(document.tasks.first.start.isUtc, isTrue);
      expect(document.tasks.first.durationDays, 2);
      expect(document.durationDays, 10);
      expect(parseGanttDate('2024-02-29'), DateTime.utc(2024, 2, 29));
      for (final invalid in [
        '2026-02-29',
        '2026-11-31',
        '2026-13-01',
        '0000-01-01',
        '2026-1-1',
        '2026-11-01T00:00:00Z',
      ]) {
        expect(
          () => parseGanttDate(invalid),
          throwsFormatException,
          reason: invalid,
        );
      }
      final day = GanttDocument.fromJson({
        'tasks': [
          {
            'id': 'one',
            'title': 'One day',
            'start': '2026-11-02',
            'end': '2026-11-02',
          },
        ],
      });
      expect(day.durationDays, 1);
      expect(day.tasks.single.durationDays, 1);
    },
  );
  test(
    'invalid dates, progress and dependency graphs preserve the previous state',
    () {
      final state = GanttChartState()..restore(fixture());
      final before = state.toJson();
      final tasks = before['tasks'] as List;
      final variants = <Map<String, dynamic>>[
        {...before, 'tasks': []},
        {...before, 'timelineScale': 'invalid'},
        {
          ...before,
          'tasks': [
            {...tasks[0] as Map, 'end': '2026-11-01'},
            ...tasks.skip(1),
          ],
        },
        for (final value in [-1, 101, double.nan, null, '50'])
          {
            ...before,
            'tasks': [
              {...tasks[0] as Map, 'progress': value},
              ...tasks.skip(1),
            ],
          },
        {
          ...before,
          'tasks': [
            {...tasks[0] as Map, 'id': 'write'},
            ...tasks.skip(1),
          ],
        },
        {
          ...before,
          'tasks': [
            {
              ...tasks[0] as Map,
              'dependencies': ['missing'],
            },
            ...tasks.skip(1),
          ],
        },
        {
          ...before,
          'tasks': [
            {
              ...tasks[0] as Map,
              'dependencies': ['plan'],
            },
            ...tasks.skip(1),
          ],
        },
        {
          ...before,
          'tasks': [
            {
              ...tasks[0] as Map,
              'dependencies': ['review'],
            },
            ...tasks.skip(1),
          ],
        },
      ];
      for (final invalid in variants) {
        expect(() => state.restore(invalid), throwsFormatException);
        expect(state.toJson(), before);
      }
      state.dispose();
    },
  );
  test('schedule conflicts are warnings and never move task dates', () {
    final json = fixture();
    json['tasks'][1]['start'] = '2026-11-03';
    final document = GanttDocument.fromJson(json);
    expect(document.warnings.single, contains('Write starts before Plan'));
    expect(ganttDate(document.tasks[1].start), '2026-11-03');
  });
  test('timeline ticks stay bounded over short and very long date ranges', () {
    for (final scale in GanttScale.values) {
      final document = GanttDocument.fromJson({
        'timelineScale': scale.name,
        'tasks': [
          {
            'id': 'long',
            'title': 'Long',
            'start': '0001-01-01',
            'end': '9999-12-31',
          },
        ],
      });
      final ticks = ganttTimelineTicks(document);
      expect(ticks, isNotEmpty);
      expect(ticks.length, lessThanOrEqualTo(25));
      expect(
        ticks.every(
          (t) => !t.isBefore(document.start) && !t.isAfter(document.end),
        ),
        isTrue,
      );
    }
  });
  testWidgets('Gantt charts save and reload tasks, progress and dependencies', (
    tester,
  ) async {
    final component = GanttChartComponent(id: 'stored')
      ..state.restore(trackingFixture());
    final settings = DocumentSettingsController();
    final theme = PageSettingsController(settings);
    await tester.runAsync(() async {
      final directory = await Directory.systemTemp.createTemp('gantt_test');
      try {
        await BookletFile.savePage(
          directory.path,
          PageContent(
            id: 'p',
            title: 'Tasks',
            components: [ComponentBox(component: component)],
          ),
        );
        final page = await BookletFile.loadPage(directory.path, 'p', theme);
        expect(page.components.single.component.def.key, 'gantt_chart');
        expect(
          (page.components.single.component.state as GanttChartState).toJson(),
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
  test('tracking baselines survive snapshots and standard views; old files default to standard', () {
    expect(GanttDocument.fromJson(fixture()).type, GanttChartType.standard);
    final document = GanttDocument.fromJson(trackingFixture());
    expect(document.type, GanttChartType.tracking);
    expect(ganttDate(document.start), '2026-10-31');
    expect(ganttDate(document.end), '2026-11-13');
    final standard = GanttDocument.fromJson({
      ...document.toJson(),
      'chartType': 'standard',
    });
    expect(ganttDate(standard.start), '2026-11-02');
    expect(ganttDate(standard.end), '2026-11-11');
    expect(
      standard.tasks.first.baselineStart,
      document.tasks.first.baselineStart,
    );
    final component = GanttChartComponent(id: 'baseline')
      ..state.restore(document.toJson());
    final copy = ComponentSnapshot.capture(ComponentBox(component: component))
        .instantiate();
    expect(
      (copy.component.state as GanttChartState).toJson(),
      document.toJson(),
    );
    component.dispose();
    copy.component.dispose();
  });
  test('baseline pairs and chart type are validated atomically', () {
    final state = GanttChartState()..restore(trackingFixture());
    final before = state.toJson();
    final tasks = before['tasks'] as List;
    for (final invalid in [
      {...before, 'chartType': 'unknown'},
      {
        ...before,
        'tasks': [
          {...tasks[0] as Map, 'baselineStart': null},
          ...tasks.skip(1),
        ],
      },
      {
        ...before,
        'tasks': [
          {...tasks[0] as Map, 'baselineEnd': '2026-02-30'},
          ...tasks.skip(1),
        ],
      },
      {
        ...before,
        'tasks': [
          {...tasks[0] as Map, 'baselineEnd': '2026-01-01'},
          ...tasks.skip(1),
        ],
      },
    ]) {
      expect(() => state.restore(invalid), throwsFormatException);
      expect(state.toJson(), before);
    }
    state.dispose();
  });
  testWidgets(
    'type selector captures a baseline without changing it as current dates move',
    (tester) async {
      final state = GanttChartState()..restore(fixture());
      await tester.pumpWidget(
        MaterialApp(home: GanttChartEditor(state: state)),
      );
      await chooseType(tester, GanttChartType.tracking);
      expect(find.textContaining('No baseline yet'), findsOneWidget);
      await tab(tester, 'Tasks');
      await tester.ensureVisible(find.text('Capture baseline'));
      await tester.tap(find.text('Capture baseline'));
      await tester.pumpAndSettle();
      final end = taskCell('Task 2 end date');
      await tester.ensureVisible(end);
      await tester.enterText(end, '2026-11-10');
      await tab(tester, 'Preview');
      var document = tester
          .widget<GanttChartPreview>(find.byType(GanttChartPreview))
          .state
          .document;
      expect(document.type, GanttChartType.tracking);
      expect(ganttDate(document.tasks[1].end), '2026-11-10');
      expect(ganttDate(document.tasks[1].baselineEnd!), '2026-11-08');
      expect(find.text('Gray bars: baseline'), findsOneWidget);
      await chooseType(tester, GanttChartType.standard);
      document = tester
          .widget<GanttChartPreview>(find.byType(GanttChartPreview))
          .state
          .document;
      expect(document.type, GanttChartType.standard);
      expect(document.tasks[1].hasBaseline, isTrue);
      expect(find.text('Gray bars: baseline'), findsNothing);
      await chooseType(tester, GanttChartType.tracking);
      await tab(tester, 'Raw data');
      final raw = jsonDecode(
        tester
            .widget<TextField>(find.byKey(const ValueKey('gantt-raw-data')))
            .controller!
            .text,
      );
      expect(raw['chartType'], 'tracking');
      expect(raw['tasks'][1]['baselineEnd'], '2026-11-08');
      expect(state.document.type, GanttChartType.standard);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
  testWidgets(
    'raw baseline edits synchronize type, task cells and thumbnails',
    (tester) async {
      final state = GanttChartState()..restore(fixture());
      await tester.pumpWidget(
        MaterialApp(home: GanttChartEditor(state: state)),
      );
      await tab(tester, 'Raw data');
      await tester.enterText(
        find.byKey(const ValueKey('gantt-raw-data')),
        jsonEncode(trackingFixture()),
      );
      await tester.pump();
      expect(
        tester
            .widget<DropdownButtonFormField<GanttChartType>>(
              find.byType(DropdownButtonFormField<GanttChartType>),
            )
            .initialValue,
        GanttChartType.tracking,
      );
      await tab(tester, 'Tasks');
      expect(taskCell('Task 1 baseline start date'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(taskCell('Task 1 baseline start date'))
            .controller!
            .text,
        '2026-10-31',
      );
      await tester.ensureVisible(find.text('Clear baseline'));
      await tester.tap(find.text('Clear baseline'));
      await tester.pumpAndSettle();
      await tab(tester, 'Preview');
      expect(
        tester
            .widget<GanttChartPreview>(find.byType(GanttChartPreview))
            .state
            .document
            .tasks
            .every((t) => !t.hasBaseline),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
      state.dispose();
      final component = GanttChartComponent(id: 'tracking-mini')
        ..state.restore(trackingFixture());
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 150,
              height: 30,
              child: ComponentMinimapPreview(
                box: ComponentBox(component: component),
              ),
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<GanttChartPreview>(find.byType(GanttChartPreview))
            .state
            .document
            .type,
        GanttChartType.tracking,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      component.dispose();
    },
  );
  testWidgets('read-only pages offer a non-editable full-screen preview', (
    tester,
  ) async {
    final component = GanttChartComponent(id: 'readonly')
      ..state.restore(fixture());
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
    expect(find.text('Edit Gantt chart'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Preview Gantt chart'));
    await tester.pumpAndSettle();
    expect(find.byType(GanttChartFullscreenPreview), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    component.dispose();
    theme.dispose();
    settings.dispose();
  });
  testWidgets(
    'task cells, raw JSON and preview synchronize without losing invalid text',
    (tester) async {
      final state = GanttChartState()..restore(fixture());
      await tester.pumpWidget(
        MaterialApp(home: GanttChartEditor(state: state)),
      );
      await tab(tester, 'Tasks');
      await tester.enterText(input('Write'), 'Draft chapter');
      await tester.enterText(input('40.0'), '65');
      await tab(tester, 'Raw data');
      final field = find.byKey(const ValueKey('gantt-raw-data'));
      final json = jsonDecode(
        tester.widget<TextField>(field).controller!.text,
      ) as Map<String, dynamic>;
      expect(json['tasks'][1]['title'], 'Draft chapter');
      expect(json['tasks'][1]['progress'], 65);
      expect(json['tasks'][2]['dependencies'], ['write']);
      json['tasks'][1]['title'] = 'Revised chapter';
      json['tasks'][1]['progress'] = 80;
      await tester.enterText(field, jsonEncode(json));
      await tab(tester, 'Tasks');
      expect(input('Revised chapter'), findsOneWidget);
      expect(input('80.0'), findsOneWidget);
      await tester.enterText(input('80.0'), 'not a number');
      await tester.pump();
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
            .onPressed,
        isNull,
      );
      expect(input('not a number'), findsOneWidget);
      await tab(tester, 'Preview');
      expect(
        tester
            .widget<GanttChartPreview>(find.byType(GanttChartPreview))
            .state
            .document
            .tasks[1]
            .progress,
        80,
      );
      expect(state.document.tasks[1].title, 'Write');
      await tab(tester, 'Raw data');
      await tester.enterText(field, '{');
      await tester.pump();
      expect(tester.widget<TextField>(field).controller!.text, '{');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
  testWidgets(
    'renaming, dependencies, ordering and deletion retain valid task IDs',
    (tester) async {
      final state = GanttChartState()..restore(fixture());
      await tester.pumpWidget(
        MaterialApp(home: GanttChartEditor(state: state)),
      );
      await tab(tester, 'Tasks');
      await tester.enterText(input('Plan'), 'Outline');
      final picker = find.byTooltip('Choose dependencies for Review');
      await tester.ensureVisible(picker);
      await tester.tap(picker);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is CheckedPopupMenuItem<String> && w.value == 'plan',
        ),
      );
      await tester.pumpAndSettle();
      final down = find.byTooltip('Move task down').first;
      await tester.ensureVisible(down);
      await tester.tap(down);
      await tester.pumpAndSettle();
      await tab(tester, 'Preview');
      var doc = tester
          .widget<GanttChartPreview>(find.byType(GanttChartPreview))
          .state
          .document;
      expect(doc.tasks.first.id, 'write');
      expect(doc.tasks.last.dependencies, ['write', 'plan']);
      await tab(tester, 'Tasks');
      final remove = find.byTooltip('Remove task').first;
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      await tab(tester, 'Preview');
      doc = tester
          .widget<GanttChartPreview>(find.byType(GanttChartPreview))
          .state
          .document;
      expect(doc.tasks.map((t) => t.id), ['plan', 'review']);
      expect(doc.tasks.last.dependencies, ['plan']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
  testWidgets(
    'add task and date picker work while tab changes reuse task inputs',
    (tester) async {
      final state = GanttChartState()..restore(fixture());
      await tester.pumpWidget(
        MaterialApp(home: GanttChartEditor(state: state)),
      );
      await tab(tester, 'Tasks');
      await tester.ensureVisible(find.text('Add task'));
      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();
      expect(input('New task'), findsOneWidget);
      final picker = find.byTooltip('Choose Task 1 start date');
      await tester.ensureVisible(picker);
      await tester.tap(picker);
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      for (final count in [1, 3, 2]) {
        await tab(tester, 'Raw data');
        final json = fixture();
        json['tasks'] = (json['tasks'] as List).take(count).toList();
        await tester.enterText(
          find.byKey(const ValueKey('gantt-raw-data')),
          jsonEncode(json),
        );
        await tab(tester, 'Tasks');
        expect(find.byTooltip('Remove task'), findsNWidgets(count));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
  testWidgets('Save applies changes and back discards the editor draft', (
    tester,
  ) async {
    final state = GanttChartState()..restore(fixture());
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => GanttChartEditor(state: state),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tab(tester, 'Tasks');
    await tester.enterText(
      find.byKey(const ValueKey('gantt-title')),
      'Discarded',
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(state.document.title, 'Book project');
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tab(tester, 'Tasks');
    await tester.enterText(find.byKey(const ValueKey('gantt-title')), 'Saved');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(state.document.title, 'Saved');
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
  testWidgets('timeline scales render and minimap thumbnails fit and update', (
    tester,
  ) async {
    final component = GanttChartComponent(id: 'mini');
    final box = ComponentBox(component: component);
    for (final scale in GanttScale.values) {
      component.state.restore({...fixture(), 'timelineScale': scale.name});
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GanttChartPreview(state: component.state)),
        ),
      );
      expect(tester.takeException(), isNull);
    }
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
        find.byType(GanttChartPreview),
      );
      final rect = MatrixUtils.transformRect(
        chart.getTransformTo(root),
        Offset.zero & chart.size,
      );
      expect(rect.top, greaterThanOrEqualTo(-.001));
      expect(rect.bottom, lessThanOrEqualTo(height + .001));
      expect(tester.takeException(), isNull);
    }
    component.state.restore({...fixture(), 'title': 'Updated thumbnail'});
    await tester.pump();
    expect(find.text('Updated thumbnail'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    component.dispose();
  });
}
