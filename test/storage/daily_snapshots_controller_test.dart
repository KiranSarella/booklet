import 'dart:io';

import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/editor_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/business/page_content.dart';
import 'package:booklet/storage/booklet_file.dart';
import 'package:booklet/storage/daily_snapshots.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/components/inbuilt_components/inbuilt_components.dart';
import 'package:booklet/ui/sidebar/document_settings/document_settings_view.dart';
import 'package:booklet/ui/sidebar/document_settings/document_settings_vm.dart';
import 'package:booklet/ui/sidebar/pages_navigation/navigation_node.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory package;
  late DocumentSettingsController settings;
  late PageSettingsController theme;
  late EditorController editor;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = DocumentSettingsController();
    theme = PageSettingsController(settings);
    editor = EditorController(theme, settings);
    package = await Directory.systemTemp.createTemp('snapshot_controller_test');
    final page = PageContent(
      id: 'page',
      title: 'Page',
      components: [
        ComponentBox(
          component: InbuiltComponents.prepareCompoent('text', 'text'),
        ),
      ],
    );
    (page.components.single.component.state as TextComponentState)
        .controller
        .document
        .insert(0, 'old');
    await BookletFile.savePage(package.path, page);
    await BookletFile.saveManifest(
      packagePath: package.path,
      groups: [NavigationNode.page(title: 'Page', pageId: 'page')],
      selectedPageId: 'page',
    );
    page.dispose();
    await Directory(DailySnapshots.root(package.path)).create();
    await File('${DailySnapshots.root(package.path)}/last_day')
        .writeAsString('2000-01-01');
    await DailySnapshots.copyPackage(
      package.path,
      '${DailySnapshots.root(package.path)}/2000-01-01',
    );
    await editor.openBookletAtPath(package.path);
  });
  tearDown(() async {
    editor.dispose();
    theme.dispose();
    settings.dispose();
    await package.delete(recursive: true);
  });
  TextComponentState state() =>
      editor.selectedPage!.components.single.component.state
          as TextComponentState;
  void setText(String text) => state().controller.replaceText(
    0,
    state().controller.document.length - 1,
    text,
    const TextSelection.collapsed(offset: 0),
  );

  test('opening and autosaving do not create backups; manual backup saves latest content', () async {
    await editor.clearDailySnapshots();
    await editor.openBookletAtPath(package.path);
    expect(editor.dailySnapshots, isEmpty);
    setText('latest');
    await editor.flushAutoSave();
    expect(await DailySnapshots.list(package.path), isEmpty);
    await editor.createManualBackup();
    expect(editor.snapshotError, null);
    final id = editor.dailySnapshots.single.day;
    await editor.restoreDailySnapshot(id);
    expect(state().output, 'latest\n');
  });

  test('restore isolates autosave, discard returns original, keep survives reopening', () async {
    expect(editor.dailySnapshots.single.day, '2000-01-01');
    setText('current');
    await editor.flushAutoSave();
    await editor.restoreDailySnapshot('2000-01-01');
    expect(editor.snapshotError, null);
    expect(state().output, 'old\n');
    expect(editor.examiningSnapshot, true);
    setText('examined');
    await editor.flushAutoSave();
    final original = await BookletFile.loadPage(package.path, 'page', theme);
    expect(
      (original.components.single.component.state as TextComponentState).output,
      'current\n',
    );
    original.dispose();
    await editor.discardRestoredChanges();
    expect(state().output, 'current\n');
    expect(editor.examiningSnapshot, false);
    await editor.restoreDailySnapshot('2000-01-01');
    setText('keep me');
    await editor.keepRestoredChanges();
    expect(editor.snapshotError, null);
    expect(state().output, 'keep me\n');
    expect(editor.lastRestoredSnapshotDay, '2000-01-01');
    expect(editor.examiningSnapshot, false);
    await editor.openBookletAtPath(package.path);
    expect(state().output, 'keep me\n');
  });

  test('unresolved examination resumes after reopening', () async {
    await editor.restoreDailySnapshot('2000-01-01');
    setText('pending examination');
    await editor.flushAutoSave();
    await editor.openBookletAtPath(package.path);
    expect(editor.examiningSnapshot, true);
    expect(state().output, 'pending examination\n');
    await editor.discardRestoredChanges();
    expect(state().output, 'old\n');
  });

  testWidgets('settings identify restored snapshot and offer safe exit', (
    tester,
  ) async {
    await tester.runAsync(() => editor.restoreDailySnapshot('2000-01-01'));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: DocumentSettingsView(
              viewModel: DocumentSettingsVM(
                settingsController: settings,
                editorController: editor,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Backups'), findsOneWidget);
    await tester.ensureVisible(find.text('Backups'));
    await tester.tap(find.text('Backups'));
    await tester.pumpAndSettle();
    expect(find.text('Restored · examining'), findsOneWidget);
    expect(find.text('Discard restored changes'), findsOneWidget);
    expect(find.text('Keep this version'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Restore'))
          .onPressed,
      null,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
