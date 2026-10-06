import 'package:booklet/application/asset_manager_controller.dart';
import 'package:booklet/business/booklet_asset.dart';
import 'package:booklet/ui/detail/assets/asset_manager_view.dart';
import 'package:booklet/ui/sidebar/pages_navigation/navigation_node.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('switches between list and icon asset views', (tester) async {
    final folder =
        NavigationNode.assetsFolder(
            title: 'Reference files',
            folderId: 'folder-1',
          )
          ..assets.add(
            const BookletAsset(
              id: 'asset-1',
              name: 'zeta.png',
              path: 'assets/folder-1/asset-1.png',
            ),
          )
          ..assets.add(
            const BookletAsset(
              id: 'asset-2',
              name: 'alpha.png',
              path: 'assets/folder-1/asset-2.png',
            ),
          )
          ..assets.add(
            const BookletAsset(
              id: 'asset-3',
              name: 'Beta.png',
              path: 'assets/folder-1/asset-3.png',
            ),
          );
    final controller = AssetManagerController()..selectFolder(folder, null);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AssetManagerView(controller: controller)),
      ),
    );

    expect(find.text('Reference files'), findsOneWidget);
    expect(find.text('alpha.png'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('alpha.png')).dy,
      lessThan(tester.getTopLeft(find.text('Beta.png')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Beta.png')).dy,
      lessThan(tester.getTopLeft(find.text('zeta.png')).dy),
    );
    await tester.tap(find.text('alpha.png'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(controller.selectedAsset?.name, 'alpha.png');
    expect(find.byTooltip('Close preview'), findsNothing);

    await tester.tap(find.byTooltip('More asset options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close preview'), findsOneWidget);
    await tester.tap(find.byTooltip('Close preview'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.grid_view_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('alpha.png'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('alpha.png')).dx,
      lessThan(tester.getTopLeft(find.text('Beta.png')).dx),
    );
    expect(
      tester.getTopLeft(find.text('Beta.png')).dx,
      lessThan(tester.getTopLeft(find.text('zeta.png')).dx),
    );

    await tester.tap(find.text('alpha.png'));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.text('alpha.png'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close preview'), findsOneWidget);
  });

  testWidgets('renames and deletes the selected asset from More', (
    tester,
  ) async {
    final folder =
        NavigationNode.assetsFolder(
            title: 'Reference files',
            folderId: 'folder-1',
          )
          ..assets.add(
            const BookletAsset(
              id: 'asset-1',
              name: 'original.txt',
              path: 'assets/folder-1/asset-1.txt',
            ),
          );
    final controller = AssetManagerController()..selectFolder(folder, null);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AssetManagerView(controller: controller)),
      ),
    );

    await tester.tap(find.text('original.txt'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More asset options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'renamed');
    await tester.tap(find.text('Rename').last);
    await tester.pumpAndSettle();
    expect(find.text('renamed.txt'), findsOneWidget);

    await tester.tap(find.byTooltip('More asset options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('No assets in this folder'), findsOneWidget);
    expect(controller.selectedAsset, isNull);
  });
}
