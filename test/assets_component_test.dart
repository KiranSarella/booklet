import 'package:booklet/application/asset_manager_controller.dart';

import 'dart:ui' as ui;
import 'dart:io';

import 'package:booklet/business/page_content.dart';
import 'package:booklet/storage/booklet_file.dart';
import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/business/booklet_asset.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_snapshot.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/assets_component.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'missing image thumbnails generate without a package and survive saving',
    () async {
      SharedPreferences.setMockInitialValues({});
      final directory = await Directory.systemTemp.createTemp(
        'asset_thumbnail_test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawColor(const ui.Color(0xFF123456), ui.BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(4, 4);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      final source = File('${directory.path}/image.png');
      await source.writeAsBytes(bytes!.buffer.asUint8List());
      final component = AssetsComponent(id: 'assets');
      final state = component.state;
      state.folder.assets.add(
        BookletAsset(id: 'image', name: 'image.png', path: source.path),
      );
      var changed = 0;
      state.addListener(() => changed++);
      await state.controller.generateMissingThumbnails();
      final thumbnail = File(state.folder.assets.single.thumbnailPath!);
      addTearDown(() => thumbnail.parent.delete(recursive: true));
      expect(await thumbnail.length(), greaterThan(0));
      expect(changed, 1);
      await state.controller.generateMissingThumbnails();
      expect(state.folder.assets.single.thumbnailPath, thumbnail.path);
      expect(changed, 1);
      final page = PageContent(
        id: 'page',
        title: 'Page',
        components: [ComponentBox(component: component)],
      );
      addTearDown(page.dispose);
      final package = '${directory.path}/package';
      await BookletFile.savePage(package, page);
      await thumbnail.delete();
      final settings = DocumentSettingsController();
      final theme = PageSettingsController(settings);
      addTearDown(settings.dispose);
      addTearDown(theme.dispose);
      final loaded = await BookletFile.loadPage(package, 'page', theme);
      addTearDown(loaded.dispose);
      final loadedState =
          loaded.components.single.component.state as AssetsComponentState;
      final savedThumbnail = File(
        loadedState.folder.assets.single.thumbnailPath!,
      );
      expect(await savedThumbnail.length(), greaterThan(0));
      await savedThumbnail.delete();
      await loadedState.controller.generateMissingThumbnails();
      final regenerated = File(loadedState.folder.assets.single.thumbnailPath!);
      addTearDown(() => regenerated.parent.delete(recursive: true));
      expect(await regenerated.length(), greaterThan(0));
    },
  );

  test('assets survive save, reopen, and save to another package', () async {
    SharedPreferences.setMockInitialValues({});
    final directory = await Directory.systemTemp.createTemp('inline_assets');
    addTearDown(() => directory.delete(recursive: true));
    final source = File('${directory.path}/source.txt');
    await source.writeAsString('attachment');
    final settings = DocumentSettingsController();
    final theme = PageSettingsController(settings);
    addTearDown(settings.dispose);
    addTearDown(theme.dispose);
    final component = AssetsComponent(id: 'assets');
    component.state.folder.assets.add(
      BookletAsset(id: 'file', name: 'source.txt', path: source.path),
    );
    final page = PageContent(
      id: 'page',
      title: 'Page',
      components: [ComponentBox(component: component)],
    );
    addTearDown(page.dispose);
    final firstPackage = '${directory.path}/first';
    await BookletFile.savePage(firstPackage, page);
    await source.delete();
    final loaded = await BookletFile.loadPage(firstPackage, 'page', theme);
    addTearDown(loaded.dispose);
    final state =
        loaded.components.single.component.state as AssetsComponentState;
    expect(
      await File(state.folder.assets.single.path).readAsString(),
      'attachment',
    );
    final secondPackage = '${directory.path}/second';
    await BookletFile.savePage(secondPackage, loaded);
    await Directory(firstPackage).delete(recursive: true);
    final reopened = await BookletFile.loadPage(secondPackage, 'page', theme);
    addTearDown(reopened.dispose);
    final reopenedState =
        reopened.components.single.component.state as AssetsComponentState;
    expect(
      await File(reopenedState.folder.assets.single.path).readAsString(),
      'attachment',
    );
  });

  testWidgets('assets fill page width and expand into a dismissible dialog', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = DocumentSettingsController();
    final theme = PageSettingsController(settings);
    final component = AssetsComponent(id: 'assets');
    addTearDown(component.dispose);
    addTearDown(theme.dispose);
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: component.buildUI(
              theme: theme,
              componentState: component.state,
              isSelected: true,
              onSelect: () {},
              onCreateBelow: () {},
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('No assets in this folder'), findsOneWidget);
    await tester.tap(find.text('Icons'));
    await tester.pumpAndSettle();
    expect(component.state.controller.layout, AssetLayout.icons);
    await tester.tap(find.byTooltip('Expand assets'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    final modeToggle = find.byType(SegmentedButton<AssetLayout>);
    expect(tester.widget<SegmentedButton<AssetLayout>>(modeToggle.last).selected, {
      AssetLayout.icons,
    });
    await tester.tap(find.text('List').last);
    await tester.pumpAndSettle();
    expect(component.state.controller.layout, AssetLayout.list);
    await tester.tap(find.byTooltip('Close preview'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(tester.widget<SegmentedButton<AssetLayout>>(modeToggle.last).selected, {
      AssetLayout.list,
    });
    await tester.tap(find.byTooltip('Expand assets'));
    await tester.pumpAndSettle();
    expect(tester.widget<SegmentedButton<AssetLayout>>(modeToggle.last).selected, {
      AssetLayout.list,
    });
    await tester.tap(find.byTooltip('Close preview'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('asset snapshots have independent collections and storage folders', () {
    final original = AssetsComponent(id: 'original');
    original.state.folder.assets.add(
      const BookletAsset(id: 'file', name: 'file.txt', path: '/tmp/file.txt'),
    );
    final copied = ComponentSnapshot.capture(ComponentBox(component: original))
        .instantiate();
    final state = copied.component.state as AssetsComponentState;
    expect(state.output, original.state.output);
    expect(state.folder.folderId, isNot(original.state.folder.folderId));
    state.folder.assets.clear();
    expect(original.state.folder.assets, hasLength(1));
    original.dispose();
    copied.component.dispose();
  });
}
