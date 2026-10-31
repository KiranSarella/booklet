import 'dart:io';

import 'package:booklet/application/appearance_mode.dart';

import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/business/page_content.dart';
import 'package:booklet/storage/booklet_file.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_snapshot.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/table_component.dart';
import 'package:booklet/ui/components/table/table_document.dart';
import 'package:booklet/ui/components/table/table_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('structure preserves cells and retains at least one row and column', () {
    final state = TableComponentState();
    state.rows[0][0].text = 'Original';
    state.insertRow(0);
    state.insertColumn(0);
    expect(state.rows[1][1].text, 'Original');
    state.removeRow(0);
    state.removeColumn(0);
    expect(state.rows[0][0].text, 'Original');
    for (var i = 0; i < 5; i++) {
      state.removeRow(0);
      state.removeColumn(0);
    }
    expect(state.rows.length, 1);
    expect(state.columnCount, 1);
    state.dispose();
  });
  test(
    'column percentages follow structural edits and old tables default to 100%',
    () {
      final state = TableComponentState();
      state.setColumnWidthPercentage(0, 60);
      state.setColumnWidthPercentage(1, 25);
      state.setColumnWidthPercentage(2, 120);
      expect(state.tableWidth, closeTo(328, 0.001));
      state.insertColumn(1);
      expect(List.generate(4, state.columnWidthPercentage), [60, 100, 25, 120]);
      state.removeColumn(0);
      expect(List.generate(3, state.columnWidthPercentage), [100, 25, 120]);
      final legacy = state.toJson()..remove('columnWidthPercentages');
      state.restore(legacy);
      expect(List.generate(3, state.columnWidthPercentage), [100, 100, 100]);
      state.dispose();
    },
  );
  for (final documentDark in [true, false]) {
    testWidgets(
      'inline table uses page appearance with documentDark=$documentDark',
      (tester) async {
        final component = TableComponent(id: 'appearance');
        component.state.rows[1][0].text = 'Body cell';
        component.state.rows[1][1] = TableCellData(
          text: 'Filled cell',
          color: Colors.yellow.toARGB32(),
        );
        final document = DocumentSettingsController();
        document.updateAppearanceMode(
          documentDark
              ? DocumentAppearanceMode.dark
              : DocumentAppearanceMode.light,
        );
        final page = PageSettingsController(document);
        page.updateAppearanceMode(
          documentDark ? EditorAppearanceMode.light : EditorAppearanceMode.dark,
        );
        page.updateTextColor(documentDark ? Colors.indigo : Colors.cyanAccent);
        await tester.pumpWidget(
          MaterialApp(
            theme: documentDark ? ThemeData.dark() : ThemeData.light(),
            home: Scaffold(
              body: component.buildUI(
                theme: page,
                componentState: component.state,
                isSelected: true,
                onSelect: () {},
                onCreateBelow: () {},
              ),
            ),
          ),
        );
        expect(
          tester.widget<Text>(find.text('Body cell')).style!.color,
          page.textColor,
        );
        expect(
          tester.widget<Text>(find.text('Body cell')).style!.fontSize,
          page.baseFontSize,
        );
        expect(
          tester.widget<Text>(find.text('Filled cell')).style!.color,
          Colors.black,
        );
        page.updateTextColor(Colors.purple);
        await tester.pump();
        expect(
          tester.widget<Text>(find.text('Body cell')).style!.color,
          Colors.purple,
        );
        await tester.tap(find.text('Edit table'));
        await tester.pumpAndSettle();
        final editorColors = Theme.of(tester.element(find.byType(TablePreview)))
            .colorScheme;
        expect(
          editorColors.brightness,
          documentDark ? Brightness.dark : Brightness.light,
        );
        expect(
          tester.widget<Text>(find.text('Body cell')).style!.color,
          editorColors.onSurface,
        );
        await tester.pumpWidget(const SizedBox());
        component.dispose();
        page.dispose();
        document.dispose();
      },
    );
  }
  testWidgets('column width changes render and support undo redo', (
    tester,
  ) async {
    final state = TableComponentState();
    await tester.pumpWidget(MaterialApp(home: TableEditor(state: state)));
    final dropdown = find.byKey(const ValueKey('column-width-percentage'));
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Column width 60%').last);
    await tester.pumpAndSettle();
    TableComponentState draft() =>
        tester.widget<TablePreview>(find.byType(TablePreview)).state;
    expect(draft().widthForColumn(0), 96);
    expect(draft().widthForColumn(1), 160);
    final table = tester.widget<Table>(find.byType(Table));
    expect((table.columnWidths![0]! as FixedColumnWidth).value, 96);
    expect(state.columnWidthPercentage(0), 100);
    await tester.tap(find.byTooltip('Undo'));
    await tester.pump();
    expect(draft().columnWidthPercentage(0), 100);
    await tester.tap(find.byTooltip('Redo'));
    await tester.pump();
    expect(draft().columnWidthPercentage(0), 60);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
  testWidgets(
    'cell fills cover the tallest cell and wide tables scroll in both views',
    (tester) async {
      final component = TableComponent(id: 'wide');
      final state = component.state;
      state.header = false;
      state.striped = true;
      state.columnWidth = 400;
      state.rows[1][0].text = 'Tall\ncell\nwith\nmultiple\nlines';
      state.rows[1][1].color = Colors.yellow.toARGB32();
      final document = DocumentSettingsController();
      final theme = PageSettingsController(document);
      Future<void> checkScroll() async {
        final scrollbar = tester.widget<Scrollbar>(
          find.descendant(
            of: find.byType(TableScrollView),
            matching: find.byType(Scrollbar),
          ),
        );
        final position = scrollbar.controller!.position;
        expect(position.maxScrollExtent, greaterThan(0));
        await tester.drag(find.byType(TablePreview), const Offset(-250, 0));
        await tester.pumpAndSettle();
        expect(position.pixels, greaterThan(0));
        position.jumpTo(0);
        await tester.pump();
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: component.buildUI(
              theme: theme,
              componentState: state,
              isSelected: false,
              onSelect: () {},
              onCreateBelow: () {},
            ),
          ),
        ),
      );
      await checkScroll();
      final filled = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).color?.toARGB32() ==
                Colors.yellow.toARGB32(),
      );
      final tall = find
          .ancestor(
            of: find.text(state.rows[1][0].text),
            matching: find.byType(Container),
          )
          .first;
      expect(tester.getSize(filled).height, tester.getSize(tall).height);
      expect(tester.getSize(filled).width, 400);
      final stripeColor = ColorScheme.fromSeed(
        seedColor: theme.styleColor,
        brightness: theme.effectiveBrightness,
      ).surfaceContainerLow;
      final striped = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).color == stripeColor,
      );
      expect(
        tester.getSize(striped.first).height,
        tester.getSize(filled).height,
      );
      await tester.pumpWidget(MaterialApp(home: TableEditor(state: state)));
      await checkScroll();
      expect(tester.getSize(filled).height, tester.getSize(tall).height);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      component.dispose();
      theme.dispose();
      document.dispose();
    },
  );
  testWidgets('compact editor supports structure and undo redo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = TableComponentState();
    await tester.pumpWidget(MaterialApp(home: TableEditor(state: state)));
    await tester.enterText(find.byType(TextField), 'Draft');
    await tester.pump();
    await tester.tap(find.byTooltip('Undo'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    await tester.tap(find.byTooltip('Redo'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Draft',
    );
    await tester.tap(find.text('Row below'));
    await tester.pump();
    expect(
      tester.widget<TablePreview>(find.byType(TablePreview)).state.rows.length,
      4,
    );
    expect(state.rows.length, 3);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
  testWidgets('table survives copy and disk persistence independently', (
    tester,
  ) async {
    final component = TableComponent(id: 'table');
    component.state.rows[0][0] = TableCellData(
      text: 'Hello',
      bold: true,
      color: 0xffffff00,
    );
    component.state.setColumnWidthPercentage(0, 60);
    component.state.setColumnWidthPercentage(1, 25);
    component.state.setColumnWidthPercentage(2, 120);
    final box = ComponentBox(component: component);
    final copy = ComponentSnapshot.fromJson(
      ComponentSnapshot.capture(box).toJson(),
    ).instantiate();
    final copied = copy.component.state as TableComponentState;
    expect(copied.toJson(), component.state.toJson());
    copied.rows[0][0].text = 'Copy';
    expect(component.state.rows[0][0].text, 'Hello');
    await tester.runAsync(() async {
      final directory = await Directory.systemTemp.createTemp('table_test');
      final document = DocumentSettingsController();
      final theme = PageSettingsController(document);
      try {
        await BookletFile.savePage(
          directory.path,
          PageContent(id: 'p', title: 'Table', components: [box]),
        );
        final restored = await BookletFile.loadPage(directory.path, 'p', theme);
        expect(
          (restored.components.single.component.state as TableComponentState)
              .toJson(),
          component.state.toJson(),
        );
        restored.components.single.component.dispose();
      } finally {
        await directory.delete(recursive: true);
        theme.dispose();
        document.dispose();
      }
    });
    copy.component.dispose();
    component.dispose();
  });
  testWidgets('page is read only and editor saves or discards a draft', (
    tester,
  ) async {
    final component = TableComponent(id: 'table');
    final document = DocumentSettingsController();
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
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Edit table'));
    await tester.pumpAndSettle();
    expect(find.byType(TableEditor), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Saved');
    expect(component.state.rows[0][0].text, '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(component.state.rows[0][0].text, 'Saved');
    await tester.tap(find.text('Edit table'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Discarded');
    await tester.tap(find.byTooltip('Close table'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(component.state.rows[0][0].text, 'Saved');
    document.updateEditMode(DocumentEditMode.readOnly);
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
    expect(find.text('Edit table'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    component.dispose();
    theme.dispose();
    document.dispose();
  });
}
