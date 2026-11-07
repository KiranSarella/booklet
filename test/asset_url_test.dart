import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:booklet/application/asset_manager_controller.dart';
import 'package:booklet/business/booklet_asset.dart';
import 'package:booklet/storage/booklet_file.dart';
import 'package:booklet/ui/sidebar/pages_navigation/navigation_node.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  test(
    'remote images cache thumbnails and survive saving and reopening',
    () async {
      final temp = await Directory.systemTemp.createTemp('asset_url_test');
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawColor(const ui.Color(0xff123456), ui.BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(4, 4);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response.headers.contentType = ContentType('image', 'png');
        request.response.add(bytes!.buffer.asUint8List());
        await request.response.close();
      });
      final folder = NavigationNode.assetsFolder(
        title: 'Assets',
        folderId: 'urls',
      );
      final controller = AssetManagerController()..selectFolder(folder, null);
      addTearDown(() async {
        controller.dispose();
        await server.close(force: true);
        await temp.delete(recursive: true);
      });
      final url = 'http://127.0.0.1:${server.port}/photo?token=123';
      await controller.addUrl(url, BookletAssetKind.image);
      final asset = folder.assets.single;
      expect(asset.kind, BookletAssetKind.image);
      expect(controller.resolvePath(asset), url);
      expect(asset.thumbnailPath, isNotNull);
      expect(await File(asset.thumbnailPath!).exists(), isTrue);
      final package = '${temp.path}/test.booklet';
      await BookletFile.saveManifest(
        packagePath: package,
        groups: [NavigationNode.group(title: 'Group')..children.add(folder)],
        selectedPageId: null,
      );
      final index = jsonDecode(
        await File('$package/assets/urls/index.json').readAsString(),
      );
      expect(index.single['url'], url);
      expect(folder.assets.single.path, url);
      expect(
        await File('$package/${folder.assets.single.thumbnailPath}').exists(),
        isTrue,
      );
      final reopened = await BookletFile.loadManifestAtPath(package);
      expect(reopened.groups.single.children.single.assets.single.path, url);
      await File(asset.thumbnailPath!).parent.delete(recursive: true);
    },
  );

  test('rejects non-web URLs without adding an asset', () async {
    final folder = NavigationNode.assetsFolder(
      title: 'Assets',
      folderId: 'urls',
    );
    final controller = AssetManagerController()..selectFolder(folder, null);
    addTearDown(controller.dispose);
    await expectLater(
      controller.addUrl('file:///tmp/image.png', BookletAssetKind.image),
      throwsArgumentError,
    );
    expect(folder.assets, isEmpty);
  });
}
