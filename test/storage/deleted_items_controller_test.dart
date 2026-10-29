import 'dart:io';

import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/editor_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/business/page_content.dart';
import 'package:booklet/business/booklet_asset.dart';
import 'package:booklet/storage/booklet_file.dart';
import 'package:booklet/storage/deleted_items.dart';
import 'package:booklet/storage/daily_snapshots.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/components/inbuilt_components/inbuilt_components.dart';
import 'package:booklet/ui/sidebar/document_settings/deleted_items_section.dart';
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
    package = await Directory.systemTemp.createTemp('deleted_controller_test');
    settings = DocumentSettingsController();
    theme = PageSettingsController(settings);
    editor = EditorController(theme, settings);
    final group = NavigationNode.group(title: 'Group');
    final parent = NavigationNode.page(title: 'Parent', pageId: 'parent');
    parent.children.add(NavigationNode.page(title: 'Child', pageId: 'child'));
    final folder =
        NavigationNode.assetsFolder(title: 'Files', folderId: 'folder')
          ..assets.add(
            const BookletAsset(
              id: 'asset',
              name: 'file.txt',
              path: 'assets/folder/asset.txt',
            ),
          );
    await Directory('${package.path}/assets/folder').create(recursive: true);
    await File('${package.path}/assets/folder/asset.txt')
        .writeAsString('asset content');
    group.children.addAll([parent, folder]);
    for (final id in ['parent', 'child']) {
      final page = PageContent(
        id: id,
        title: id,
        components: [
          ComponentBox(
            component: InbuiltComponents.prepareCompoent('text-$id', 'text'),
          ),
        ],
      );
      (page.components.single.component.state as TextComponentState)
          .controller
          .document
          .insert(0, '$id content');
      await BookletFile.savePage(package.path, page);
      page.dispose();
    }
    await BookletFile.saveManifest(
      packagePath: package.path,
      groups: [group],
      selectedPageId: 'parent',
    );
    await editor.openBookletAtPath(package.path);
  });
  tearDown(() async {
    editor.dispose();
    theme.dispose();
    settings.dispose();
    await package.delete(recursive: true);
  });

  test(
    'group delete survives reopen; restore recovers nested content and assets',
    () async {
      final state =
          editor.selectedPage!.components.single.component.state
              as TextComponentState;
      state.controller.document.insert(0, 'unsaved ');
      editor.viewModel.navigation.selectNode(
        editor.viewModel.navigation.groups.single,
      );
      await editor.deleteSelectedNode();
      expect(editor.trashError, null);
      expect(editor.viewModel.navigation.groups, isEmpty);
      expect(editor.deletedItems.single.title, 'Group');
      expect(await File('${package.path}/pages/parent.json').exists(), false);
      expect(await Directory('${package.path}/assets/folder').exists(), false);
      await editor.openBookletAtPath(package.path);
      final id = editor.deletedItems.single.id;
      await editor.restoreDeletedItem(id);
      expect(editor.trashError, null);
      expect(editor.deletedItems, isEmpty);
      final group = editor.viewModel.navigation.groups.single;
      expect(group.title, 'Group (restored)');
      final parent = group.children.first;
      expect(parent.title, 'Parent (restored)');
      expect(parent.children.single.title, 'Child (restored)');
      expect(parent.pageId, isNot('parent'));
      await editor.selectPage(parent.pageId!);
      expect(
        (editor.selectedPage!.components.single.component.state
                as TextComponentState)
            .output,
        'unsaved parent content\n',
      );
      await editor.selectPage(parent.children.single.pageId!);
      expect(
        (editor.selectedPage!.components.single.component.state
                as TextComponentState)
            .output,
        'child content\n',
      );
      final asset = group.children.last.assets.single;
      expect(
        await File('${package.path}/${asset.path}').readAsString(),
        'asset content',
      );
    },
  );

  test('single-page delete restores descendants and permanent delete removes entry', () async {
    await editor.deleteSelectedNode();
    expect(editor.deletedItems.single.title, 'Parent');
    await editor.restoreDeletedItem(editor.deletedItems.single.id);
    final restored = editor.viewModel.navigation.groups.last;
    expect(restored.title, 'Parent (restored)');
    expect(restored.children.single.title, 'Child (restored)');
    await editor.deleteSelectedNode();
    await editor.permanentlyDeleteItem(editor.deletedItems.single.id);
    expect(editor.deletedItems, isEmpty);
    expect(await DeletedItems.list(package.path), isEmpty);
  });

  test('unsaved booklet supports delete and restore', () async {
    final unsaved = EditorController(theme, settings);
    try {
      final original = unsaved.viewModel.navigation.selectedNode!.title;
      await unsaved.deleteSelectedNode();
      expect(unsaved.deletedItems.single.title, original);
      await unsaved.restoreDeletedItem(unsaved.deletedItems.single.id);
      expect(unsaved.trashError, null);
      expect(unsaved.deletedItems, isEmpty);
      expect(unsaved.selectedPage!.title, '$original (restored)');
    } finally {
      unsaved.dispose();
    }
  });

  test('read-only mode protects live and deleted items', () async {
    settings.updateEditMode(DocumentEditMode.readOnly);
    await editor.deleteSelectedNode();
    expect(editor.deletedItems, isEmpty);
    expect(
      editor.viewModel.navigation.groups.single.children.first.title,
      'Parent',
    );
  });

  test('trash changes in snapshot examinations can be discarded; permanent deletes stay deleted', () async {
    await Directory(DailySnapshots.root(package.path)).create(recursive: true);
    await File('${DailySnapshots.root(package.path)}/last_day')
        .writeAsString('2000-01-01');
    await DailySnapshots.copyPackage(
      package.path,
      '${DailySnapshots.root(package.path)}/2000-01-01',
    );
    await editor.refreshSnapshots();
    await editor.deleteSelectedNode();
    final id = editor.deletedItems.single.id;
    await editor.restoreDailySnapshot('2000-01-01');
    expect(editor.deletedItems.single.id, id);
    await editor.permanentlyDeleteItem(id);
    expect(editor.deletedItems, isEmpty);
    await editor.discardRestoredChanges();
    expect(editor.deletedItems.single.id, id);
    await editor.permanentlyDeleteItem(id);
    await editor.restoreDailySnapshot('2000-01-01');
    expect(editor.deletedItems, isEmpty);
    await editor.discardRestoredChanges();
  });

  testWidgets('trash section lists title, restore and permanent delete', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await editor.deleteSelectedNode();
      final bundle = await DeletedItems.read(
        package.path,
        editor.deletedItems.single.id,
      );
      (bundle['node'] as Map)['title'] = 'Another page';
      await DeletedItems.add(package.path, bundle);
      await editor.refreshDeletedItems();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DeletedItemsSection(controller: editor)),
      ),
    );
    expect(find.text('Deleted pages and groups'), findsOneWidget);
    await tester.tap(find.text('Deleted pages and groups'));
    await tester.pumpAndSettle();
    expect(find.text('Parent'), findsOneWidget);
    expect(find.text('Restore'), findsOneWidget);
    expect(find.text('Permanently delete'), findsOneWidget);
    TextButton button(String text) =>
        tester.widget<TextButton>(find.widgetWithText(TextButton, text));
    expect(button('Restore').onPressed, isNull);
    expect(button('Permanently delete').onPressed, isNull);
    await tester.tap(find.text('Parent'));
    await tester.pump();
    expect(button('Restore').onPressed, isNotNull);
    expect(button('Permanently delete').onPressed, isNotNull);
    expect(
      tester.widget<ListTile>(find.widgetWithText(ListTile, 'Parent')).selected,
      isTrue,
    );
    await tester.tap(find.text('Another page'));
    await tester.pump();
    expect(
      tester.widget<ListTile>(find.widgetWithText(ListTile, 'Parent')).selected,
      isFalse,
    );
    expect(
      tester
          .widget<ListTile>(find.widgetWithText(ListTile, 'Another page'))
          .selected,
      isTrue,
    );
    await tester.runAsync(
      () => editor.permanentlyDeleteItem(
        editor.deletedItems
            .firstWhere((item) => item.title == 'Another page')
            .id,
      ),
    );
    await tester.pump();
    expect(button('Restore').onPressed, isNull);
    expect(button('Permanently delete').onPressed, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
