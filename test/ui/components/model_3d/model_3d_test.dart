import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:webview_all/webview_all.dart';
import 'package:booklet/ui/components/model_3d/model_3d_thumbnail_cache.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/business/page_content.dart';
import 'package:booklet/storage/booklet_file.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_snapshot.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/model_3d_component.dart';
import 'package:booklet/ui/components/model_3d/model_3d_importer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('booklet_3d_test');
  });
  tearDown(() => directory.delete(recursive: true));

  test(
    'glTF embeds local textures and buffers and survives source deletion',
    () async {
      await File('${directory.path}/mesh.bin').writeAsBytes([0, 1, 2, 3]);
      await File('${directory.path}/texture.png')
          .writeAsBytes([137, 80, 78, 71]);
      final source = File('${directory.path}/model.gltf');
      await source.writeAsString(
        jsonEncode({
          'asset': {'version': '2.0'},
          'buffers': [
            {'uri': 'mesh.bin', 'byteLength': 4},
          ],
          'images': [
            {'uri': 'texture.png'},
          ],
        }),
      );
      final imported = await Model3dImporter.read(source);
      final json = jsonDecode(utf8.decode(imported));
      expect(
        json['buffers'][0]['uri'],
        'data:application/octet-stream;base64,AAECAw==',
      );
      expect(json['images'][0]['uri'], startsWith('data:image/png;base64,'));
      await File('${directory.path}/mesh.bin').delete();
      final packed = File('${directory.path}/packed.gltf');
      await packed.writeAsBytes(imported);
      expect(await Model3dImporter.read(packed), imported);
    },
  );

  test('rejects missing, remote and out-of-folder dependencies', () async {
    final folder = Directory('${directory.path}/model');
    await folder.create();
    await File('${directory.path}/outside.bin').writeAsBytes([0]);
    final file = File('${folder.path}/model.gltf');
    for (final uri in [
      'missing.bin',
      '../outside.bin',
      'https://example.com/mesh.bin',
    ]) {
      await file.writeAsString(
        jsonEncode({
          'asset': {'version': '2.0'},
          'buffers': [
            {'uri': uri},
          ],
        }),
      );
      await expectLater(Model3dImporter.read(file), throwsA(anything));
    }
  });

  test('accepts GLB 2.0 and rejects invalid headers', () async {
    final json = utf8.encode('{"asset":{"version":"2.0"}}  ');
    final bytes = Uint8List(20 + json.length);
    final header = ByteData.sublistView(bytes);
    header.setUint32(0, 0x46546c67, Endian.little);
    header.setUint32(4, 2, Endian.little);
    header.setUint32(8, bytes.length, Endian.little);
    header.setUint32(12, json.length, Endian.little);
    header.setUint32(16, 0x4e4f534a, Endian.little);
    bytes.setRange(20, bytes.length, json);
    final file = File('${directory.path}/model.glb');
    await file.writeAsBytes(bytes);
    expect(await Model3dImporter.read(file), bytes);
    bytes[0] = 0;
    await file.writeAsBytes(bytes);
    await expectLater(Model3dImporter.read(file), throwsFormatException);
  });

  test(
    'model attachment and caption survive save, reload and copy/paste',
    () async {
      final source = File('${directory.path}/model.gltf');
      await source.writeAsString('{"asset":{"version":"2.0"}}');
      final component = Model3dComponent(id: 'model');
      component.state.mediaPath = source.path;
      component.state.caption = 'My model';
      final box = ComponentBox(component: component);
      final page = PageContent(id: 'page-3d', title: '3D', components: [box]);
      final package = '${directory.path}/document';
      await BookletFile.savePage(package, page);
      await source.delete();
      final theme = PageSettingsController(DocumentSettingsController());
      final loaded = await BookletFile.loadPage(package, page.id, theme);
      final state =
          loaded.components.single.component.state as Model3dComponentState;
      expect(state.caption, 'My model');
      expect(await File(state.mediaPath!).exists(), isTrue);
      final snapshot = ComponentSnapshot.capture(loaded.components.single);
      final copy = snapshot.instantiate();
      expect(copy.component.def.key, 'model_3d');
      expect(
        (copy.component.state as Model3dComponentState).mediaPath,
        state.mediaPath,
      );
      expect(
        (copy.component.state as Model3dComponentState).caption,
        'My model',
      );
    },
  );

  testWidgets('empty component offers import without creating a WebView', (
    tester,
  ) async {
    final state = Model3dComponentState();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Model3dComponentView(state: state, onSelect: () {}),
        ),
      ),
    );
    expect(find.text('Choose model'), findsOneWidget);
    expect(find.textContaining('GLB or glTF'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
  testWidgets(
    'read-only component hides replacement and protects its caption',
    (tester) async {
      final state = Model3dComponentState(mediaPath: '/model.glb');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Model3dComponentView(
              state: state,
              onSelect: () {},
              readOnly: true,
              isSelected: true,
            ),
          ),
        ),
      );
      expect(find.text('Replace model'), findsNothing);
      expect(find.byTooltip('Play 3D model'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    },
  );
  testWidgets(
    'cached model shows a thumbnail and play with video-style caption selection',
    (tester) async {
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) async => directory.path);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final source = File('${directory.path}/cached.glb');
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawColor(const Color(0xff336699), ui.BlendMode.src);
      final picture = recorder.endRecording();
      final image = await tester.runAsync(() => picture.toImage(4, 4));
      final png = await tester.runAsync(
        () => image!.toByteData(format: ui.ImageByteFormat.png),
      );
      image!.dispose();
      picture.dispose();
      await tester.runAsync(() async {
        await source.writeAsBytes([1, 2, 3]);
        await Model3dThumbnailCache.save(
          source.path,
          png!.buffer.asUint8List(),
        );
      });
      final state = Model3dComponentState(mediaPath: source.path);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Model3dComponentView(state: state, onSelect: () {}),
          ),
        ),
      );
      for (
        var attempt = 0;
        attempt < 20 && find.byType(Image).evaluate().isEmpty;
        attempt++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(WebViewWidget), findsNothing);
      expect(find.byTooltip('Play 3D model'), findsOneWidget);
      expect(find.text('Choose model'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Model3dComponentView(
              state: state,
              onSelect: () {},
              isSelected: true,
            ),
          ),
        ),
      );
      expect(find.byType(TextField), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).textAlign,
        TextAlign.center,
      );
      await tester.enterText(find.byType(TextField), 'A model\nwith a caption');
      expect(state.caption, 'A model\nwith a caption');
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    },
  );
  testWidgets('selected model border stays behind the interactive surface', (
    tester,
  ) async {
    final component = Model3dComponent(id: 'selected-model');
    final box = ComponentBox(component: component)..isSelected = true;
    final theme = PageSettingsController(DocumentSettingsController());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: box.buildUI(
            theme: theme,
            onSelect: () {},
            onSelectRange: () {},
            onCreateBelow: (_) {},
            onBackspaceAtStart: () {},
            onMoveToAdjacentTextComponent: (_) {},
            onPasteText: (_) async => false,
          ),
        ),
      ),
    );
    final decoration = tester
        .widgetList<CustomPaint>(
          find.ancestor(
            of: find.byType(Model3dComponentView),
            matching: find.byType(CustomPaint),
          ),
        )
        .firstWhere((paint) => paint.painter != null);
    expect(
      decoration.foregroundPainter,
      isNull,
      reason: 'A foreground decoration can create a native WebView input-blocking overlay.',
    );
    expect(decoration.painter!.hitTest(Offset.zero), isFalse);
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Selected model caption');
    expect(component.state.caption, 'Selected model caption');
    await tester.pumpWidget(const SizedBox.shrink());
    component.dispose();
  });
}
