import 'dart:convert';
import 'dart:io';

import 'package:booklet/application/asset_manager_controller.dart';
import 'package:booklet/business/booklet_asset.dart';
import 'package:booklet/storage/booklet_file.dart';
import 'package:booklet/ui/navigation/navigation_node.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BookletFile asset storage', () {
    test('deleting an unsaved asset preserves its source file', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'booklet_unsaved_asset_test',
      );
      final source = File('${tempDir.path}/source.txt');
      await source.writeAsString('keep this source');
      final folder =
          NavigationNode.assetsFolder(title: 'Assets', folderId: 'folder-1')
            ..assets.add(
              BookletAsset(
                id: 'asset-1',
                name: 'source.txt',
                path: source.path,
              ),
            );
      final controller = AssetManagerController()..selectFolder(folder, null);
      controller.selectAsset(folder.assets.single);

      await controller.deleteSelectedAsset();

      expect(folder.assets, isEmpty);
      expect(await source.exists(), isTrue);
      controller.dispose();
      await tempDir.delete(recursive: true);
    });

    test('copies unsaved assets into the package on first save', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'booklet_asset_test',
      );
      final source = File('${tempDir.path}/source.txt');
      await source.writeAsString('asset contents');
      final assets = await BookletFile.importAssets(
        packagePath: null,
        folderId: 'folder-1',
        files: [XFile(source.path)],
      );
      final folder = NavigationNode.assetsFolder(
        title: 'Reference files',
        folderId: 'folder-1',
      )..assets.addAll(assets);
      final group = NavigationNode.group(title: 'Group')..children.add(folder);
      final packagePath = '${tempDir.path}/booklet.booklet';

      await BookletFile.saveManifest(
        packagePath: packagePath,
        groups: [group],
        selectedPageId: null,
        selectedAssetFolderId: folder.folderId,
      );

      final manifest = jsonDecode(
        await File('$packagePath/content.json').readAsString(),
      ) as Map<String, dynamic>;
      final navigation = manifest['navigation'] as List<dynamic>;
      final savedGroup = navigation.single as Map<String, dynamic>;
      final savedFolder =
          (savedGroup['children'] as List<dynamic>).single
              as Map<String, dynamic>;
      final savedAsset =
          (savedFolder['assets'] as List<dynamic>).single
              as Map<String, dynamic>;
      final copiedAsset = File('$packagePath/${savedAsset['path']}');

      expect(manifest['selectedAssetFolderId'], 'folder-1');
      expect(savedAsset['path'], startsWith('assets/folder-1/'));
      expect(await copiedAsset.readAsString(), 'asset contents');
      expect(BookletAsset.fromJson(savedAsset).name, 'source.txt');

      await BookletFile.deleteAssetsForNode(packagePath, group);
      expect(await copiedAsset.exists(), isFalse);

      await tempDir.delete(recursive: true);
    });
  });
}
