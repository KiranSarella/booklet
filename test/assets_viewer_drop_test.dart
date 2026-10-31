import 'dart:io';

import 'package:booklet/application/asset_manager_controller.dart';
import 'package:booklet/ui/detail/assets_viewer/assets_viewer.dart';
import 'package:booklet/ui/sidebar/pages_navigation/navigation_node.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('imports dropped files and ignores directories', (tester) async {
    final directory = Directory.systemTemp.createTempSync('asset_drop_test');
    addTearDown(() => directory.deleteSync(recursive: true));
    final first = File('${directory.path}/first.txt')
      ..writeAsStringSync('first');
    final second = File('${directory.path}/second.txt')
      ..writeAsStringSync('second');
    final folder = NavigationNode.assetsFolder(
      title: 'Assets',
      folderId: 'folder',
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
    final target = tester.widget<DropTarget>(find.byType(DropTarget));
    await tester.runAsync(() async {
      target.onDragDone!(
        DropDoneDetails(
          files: [
            DropItemFile(first.path),
            DropItemDirectory(directory.path, []),
            DropItemFile(second.path),
          ],
          localPosition: Offset.zero,
          globalPosition: Offset.zero,
        ),
      );
      // Wait for the asynchronous file checks and import to finish.
      for (
        var attempt = 0;
        attempt < 100 && folder.assets.length < 2;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect(folder.assets.map((asset) => asset.name), [
      'first.txt',
      'second.txt',
    ]);
    expect(find.text('first.txt'), findsOneWidget);
    expect(find.text('second.txt'), findsOneWidget);
  });

  testWidgets('read-only viewer disables file drops', (tester) async {
    final controller = AssetManagerController()
      ..selectFolder(
        NavigationNode.assetsFolder(title: 'Assets', folderId: 'folder'),
        null,
      );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssetsViewer(controller: controller, isReadOnly: true),
        ),
      ),
    );
    expect(tester.widget<DropTarget>(find.byType(DropTarget)).enable, isFalse);
    expect(find.text('Add asset'), findsNothing);
  });
}
