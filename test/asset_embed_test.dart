import 'dart:io';

import 'package:flutter/material.dart';
import 'package:booklet/ui/detail/assets_viewer/assets_viewer.dart';

import 'package:booklet/application/asset_manager_controller.dart';
import 'package:booklet/business/booklet_asset.dart';
import 'package:booklet/storage/booklet_file.dart';
import 'package:booklet/ui/components/media/asset_embed.dart';
import 'package:booklet/ui/sidebar/pages_navigation/navigation_node.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Embed input explains provider displays and validates pasted code',
    (tester) async {
      final folder = NavigationNode.assetsFolder(
        title: 'Assets',
        folderId: 'embed-ui',
      );
      final controller = AssetManagerController()..selectFolder(folder, null);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssetsViewer(controller: controller, isReadOnly: false),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Add embed'));
      await tester.pumpAndSettle();
      expect(find.textContaining('player, post, map'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField),
        '<script>bad()</script>',
      );
      await tester.tap(find.text('Add'));
      await tester.pump();
      expect(
        find.text('Enter supported embed code with a valid web address.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byType(TextFormField),
        '<iframe title="Office map" src="https://maps.example.com/embed"></iframe>',
      );
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(folder.assets.single.embedCode, contains('<iframe'));
      expect(find.text('Office map'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('iframe embeds retain remote widget target and title', () {
    final target = AssetEmbed.parse(
      '<iframe title="Map" src="https://maps.example.com/embed?a=1&amp;b=2"></iframe><script>bad()</script>',
    )!;
    expect(target.source.toString(), 'https://maps.example.com/embed?a=1&b=2');
    expect(target.title, 'Map');
    expect(target.html, isNull);
    expect(
      AssetEmbed.parse('<iframe src="javascript:bad()"></iframe>'),
      isNull,
    );
    expect(
      AssetEmbed.parse('<script src="https://example.com/widget.js"></script>'),
      isNull,
    );
  });
  test('Instagram and X embeds resolve to provider displays', () {
    final instagram = AssetEmbed.parse(
      '<blockquote class="instagram-media" data-instgrm-permalink="https://www.instagram.com/reel/DcJfWVNtLzJ/"></blockquote><script src="//www.instagram.com/embed.js"></script>',
    )!;
    expect(instagram.displayUri.path, '/p/DcJfWVNtLzJ/embed/captioned/');
    final x = AssetEmbed.parse(
      '<blockquote class="twitter-tweet"><a href="https://x.com/user/status/123456">Post</a></blockquote>',
    )!;
    expect(x.html, contains('platform.twitter.com/widgets.js'));
    expect(x.source.toString(), 'https://x.com/i/status/123456');
  });
  test('embed code survives rename, save, reopen, and JSON', () async {
    final temp = await Directory.systemTemp.createTemp('embed_assets');
    addTearDown(() => temp.delete(recursive: true));
    final folder = NavigationNode.assetsFolder(
      title: 'Assets',
      folderId: 'embeds',
    );
    final controller = AssetManagerController()..selectFolder(folder, null);
    addTearDown(controller.dispose);
    const code =
        '<iframe title="Map" src="https://maps.example.com/embed"></iframe>';
    await controller.addEmbed(code);
    expect(folder.assets.single.name, 'Map');
    controller.selectAsset(folder.assets.single);
    controller.renameSelectedAsset('Office map');
    expect(folder.assets.single.embedCode, code);
    expect(
      BookletAsset.fromJson(folder.assets.single.toJson()).embedCode,
      code,
    );
    await BookletFile.saveManifest(
      packagePath: temp.path,
      groups: [NavigationNode.group(title: 'Group')..children.add(folder)],
      selectedPageId: null,
    );
    final loaded = await BookletFile.loadManifestAtPath(temp.path);
    final asset = loaded.groups.single.children.single.assets.single;
    expect(asset.embedCode, code);
    expect(asset.path, 'https://maps.example.com/embed');
  });
}
