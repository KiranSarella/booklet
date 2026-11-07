import 'package:booklet/application/asset_manager_controller.dart';
import 'package:booklet/business/booklet_asset.dart';
import 'package:booklet/ui/detail/assets_viewer/assets_viewer.dart';
import 'package:booklet/ui/sidebar/pages_navigation/navigation_node.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('video assets show play indicators in list and icon layouts', (
    tester,
  ) async {
    final folder =
        NavigationNode.assetsFolder(title: 'Assets', folderId: 'videos')
          ..assets.add(
            const BookletAsset(
              id: 'clip',
              name: 'clip.mp4',
              path: '/missing/clip.mp4',
            ),
          );
    final controller = AssetManagerController()..selectFolder(folder, null);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssetsViewer(controller: controller, isReadOnly: true),
        ),
      ),
    );
    expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
    controller.setLayout(AssetLayout.icons);
    await tester.pump();
    expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
