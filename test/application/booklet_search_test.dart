import 'dart:io';

import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/editor_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/business/page_content.dart';
import 'package:booklet/storage/booklet_file.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/text_component.dart';
import 'package:booklet/ui/sidebar/pages_navigation/navigation_node.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test(
    'searches unloaded pages and unsaved edits without changing selection',
    () async {
      final directory = await Directory.systemTemp.createTemp('booklet_search');
      final settings = DocumentSettingsController();
      final editor = EditorController(
        PageSettingsController(settings),
        settings,
        autoSaveDelay: const Duration(hours: 1),
      );
      try {
        final group = NavigationNode.group(title: 'Chapter');
        for (final id in ['one', 'two']) {
          group.children.add(
            NavigationNode.page(title: 'Page $id', pageId: id),
          );
          final page = PageContent(
            id: id,
            title: 'Page $id',
            components: [
              ComponentBox(
                component: TextComponent(id: 'text-$id'),
                delta: [
                  {'insert': 'Saved needle a.b\n'},
                ],
              ),
            ],
          );
          await BookletFile.savePage(directory.path, page);
          page.dispose();
        }
        await BookletFile.saveManifest(
          packagePath: directory.path,
          groups: [group],
          selectedPageId: 'one',
        );
        await editor.openBookletAtPath(directory.path);
        final state =
            editor.selectedPage!.components.single.component.state
                as TextComponentState;
        state.controller.replaceText(
          0,
          0,
          'Unsaved needle ',
          state.controller.selection,
        );
        final results = await editor.searchBooklet('NEEDLE');
        expect(results.map((page) => page.pageId), ['one', 'two']);
        expect(results.first.hits, hasLength(2));
        expect(results.last.hits, hasLength(1));
        expect(results.last.breadcrumb, 'Chapter');
        expect(editor.selectedPage!.id, 'one');
        expect(editor.viewModel.loadedPages, hasLength(1));
        expect((await editor.searchBooklet('Unsaved')).single.pageId, 'one');
        expect(await editor.searchBooklet('a+b'), isEmpty);
        expect(await editor.searchBooklet(''), isEmpty);
        final titleResult = (await editor.searchBooklet('Page two')).single;
        expect(titleResult.pageId, 'two');
        expect(titleResult.hits, isEmpty);
        final hit = results.first.hits.first;
        expect(hit.text.substring(hit.start, hit.end).toLowerCase(), 'needle');
        expect(
          await editor.searchBooklet('NEEDLE', caseSensitive: true),
          isEmpty,
        );
        expect(
          await editor.searchBooklet('page two', caseSensitive: true),
          isEmpty,
        );
        expect(await editor.replaceBookletMatches('needle', 'pin'), 1);
        expect((await editor.searchBooklet('needle')).first.hits, hasLength(1));
        expect(
          await editor.replaceBookletMatches('needle', 'pin', all: true),
          2,
        );
        expect(await editor.searchBooklet('needle'), isEmpty);
        expect(editor.selectedPage!.id, 'one');
        final diskPage = await BookletFile.loadPage(
          directory.path,
          'two',
          editor.editorTheme,
        );
        try {
          expect(
            (diskPage.components.single.component.state as TextComponentState)
                .output,
            contains('pin'),
          );
        } finally {
          diskPage.dispose();
        }
      } finally {
        editor.dispose();
        await directory.delete(recursive: true);
      }
    },
  );
}
