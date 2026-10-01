import 'package:booklet/application/asset_manager_controller.dart';
import 'package:booklet/business/booklet_asset.dart';
import 'package:booklet/ui/assets/asset_manager_view.dart';
import 'package:booklet/ui/navigation/navigation_node.dart';
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
              name: 'diagram.png',
              path: 'assets/folder-1/asset-1.png',
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
    expect(find.text('diagram.png'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);

    await tester.tap(find.byIcon(Icons.grid_view_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('diagram.png'), findsOneWidget);
  });
}
