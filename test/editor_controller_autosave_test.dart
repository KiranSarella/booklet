import 'dart:convert';
import 'dart:io';

import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/editor_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/business/booklet_asset.dart';
import 'package:booklet/business/page_content.dart';
import 'package:booklet/storage/booklet_file.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/components/inbuilt_components.dart';
import 'package:booklet/ui/navigation/navigation_node.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('autosaves component edits after the debounce interval', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'booklet_autosave_test',
    );
    final packagePath = '${tempDir.path}/autosave-booklet';
    const pageId = 'autosave-page';
    const folderId = 'autosave-folder';
    const assetId = 'autosave-asset';
    final assetFile = File('$packagePath/assets/$folderId/$assetId.txt');
    await assetFile.parent.create(recursive: true);
    await assetFile.writeAsString('asset');
    final assetFolder =
        NavigationNode.assetsFolder(title: 'Assets', folderId: folderId)
          ..assets.add(
            const BookletAsset(
              id: assetId,
              name: 'before.txt',
              path: 'assets/$folderId/$assetId.txt',
            ),
          );
    final group = NavigationNode.group(title: 'Group')
      ..children.addAll([
        NavigationNode.page(title: 'Page', pageId: pageId),
        assetFolder,
      ]);
    final initialPage = PageContent(
      id: pageId,
      title: 'Page',
      components: [
        ComponentBox(
          component: InbuiltComponents.prepareCompoent('text-1', 'text'),
        ),
      ],
    );
    await BookletFile.savePage(packagePath, initialPage);
    await BookletFile.saveManifest(
      packagePath: packagePath,
      groups: [group],
      selectedPageId: pageId,
    );
    initialPage.dispose();

    final documentSettings = DocumentSettingsController();
    final editor = EditorController(
      PageSettingsController(documentSettings),
      documentSettings,
      autoSaveDelay: const Duration(milliseconds: 20),
    );

    try {
      await editor.openBookletAtPath(packagePath);
      final state =
          editor.selectedPage!.components.single.component.state
              as TextComponentState;
      state.controller.replaceText(
        0,
        0,
        'Autosaved text',
        state.controller.selection,
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final savedPage = jsonDecode(
        await File('$packagePath/pages/$pageId.json').readAsString(),
      ) as Map<String, dynamic>;
      final savedComponent =
          (savedPage['components'] as List).single as Map<String, dynamic>;
      expect(savedComponent['content'], contains('Autosaved text'));
      expect(editor.autoSaveError, isNull);

      final loadedGroup = editor.viewModel.navigation.groups.single;
      editor.viewModel.navigation.selectNode(loadedGroup);
      editor.viewModel.renameSelectedNode('Renamed group');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final loadedAssetFolder = loadedGroup.children.singleWhere(
        (node) => node.isAssetsFolder,
      );
      editor.assetManagerController.selectFolder(
        loadedAssetFolder,
        packagePath,
      );
      editor.assetManagerController.selectAsset(
        loadedAssetFolder.assets.single,
      );
      editor.assetManagerController.renameSelectedAsset('after');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final savedManifest = jsonDecode(
        await File('$packagePath/content.json').readAsString(),
      ) as Map<String, dynamic>;
      final savedGroup = NavigationNode.fromJson(
        (savedManifest['navigation'] as List).single as Map<String, dynamic>,
      );
      expect(savedGroup.title, 'Renamed group');
      expect(savedGroup.children.last.assets.single.name, 'after.txt');
    } finally {
      editor.dispose();
      await tempDir.delete(recursive: true);
    }
  });
}
