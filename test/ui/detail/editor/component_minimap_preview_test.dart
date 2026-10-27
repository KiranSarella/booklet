import 'dart:convert';
import 'dart:io';

import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/editor_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/detail/editor/component_minimap_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('miniatures show headings and symbols without hover labels', (
    tester,
  ) async {
    final settings = DocumentSettingsController();
    final theme = PageSettingsController(settings);
    final controller = EditorController(theme, settings);
    final boxes = <ComponentBox>[];
    for (final kind in [
      'title',
      'heading',
      'subheading',
      'inline_heading',
      'text',
      'quote',
      'bulleted_list',
      'numbered_list',
      'checklist',
      'math',
      'code_block',
      'assets',
      'audio',
      'embed',
    ]) {
      final box = controller.viewModel.createComponentBelowType(
        controller.viewModel.components.length - 1,
        kind,
      );
      final state = box.component.state;
      if (state is TextComponentState) {
        state.controller.document.insert(0, '$kind preview');
      }
      boxes.add(box);
    }
    boxes[4].hasFocusBar = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              for (final box in boxes)
                SizedBox(
                  width: 150,
                  height: 30,
                  child: ComponentMinimapPreview(box: box),
                ),
            ],
          ),
        ),
      ),
    );
    for (final kind in ['title', 'heading', 'subheading', 'inline_heading']) {
      expect(find.text('$kind preview'), findsOneWidget);
    }
    expect(find.text('text preview'), findsNothing);
    expect(find.byType(Tooltip), findsNothing);
    expect(find.byIcon(Icons.functions), findsOneWidget);
    expect(find.byIcon(Icons.code), findsOneWidget);
    expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
    expect(find.byIcon(Icons.music_note), findsOneWidget);
    expect(find.byIcon(Icons.integration_instructions_outlined), findsOneWidget);
    expect(
      tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).any((widget) {
        final decoration = widget.decoration;
        return decoration is BoxDecoration &&
            decoration.border is Border &&
            (decoration.border! as Border).left.width == 2;
      }),
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    theme.dispose();
    settings.dispose();
  });

  testWidgets('image and video previews use actual thumbnail pixels', (
    tester,
  ) async {
    final settings = DocumentSettingsController();
    final theme = PageSettingsController(settings);
    final controller = EditorController(theme, settings);
    final directory = Directory.systemTemp.createTempSync('minimap_test_');
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aFOkAAAAASUVORK5CYII=',
    );
    final image = File('${directory.path}/image.png');
    image.writeAsBytesSync(bytes);
    var requests = 0;
    const channel = MethodChannel('booklet/video_thumbnail');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      requests++;
      File((call.arguments as Map)['thumbnailPath'] as String)
          .writeAsBytesSync(bytes);
      return true;
    });
    const pluginChannel = MethodChannel('plugins.justsoft.xyz/video_thumbnail');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      pluginChannel,
      (call) async {
        requests++;
        return bytes;
      },
    );
    final imageBox = controller.viewModel.createComponentBelowType(0, 'image');
    (imageBox.component.state as ImageComponentState).mediaPath = image.path;
    final videoBox = controller.viewModel.createComponentBelowType(1, 'video');
    (videoBox.component.state as VideoComponentState).mediaPath =
        '${directory.path}/movie.mp4';
    // Run native thumbnail and image I/O outside the simulated async clock.
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              for (final box in [imageBox, videoBox])
                SizedBox(
                  width: 150,
                  height: 80,
                  child: ComponentMinimapPreview(box: box),
                ),
            ],
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(find.byType(Image), findsNWidgets(2));
    expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
    expect(find.byType(Tooltip), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      pluginChannel,
      null,
    );
    controller.dispose();
    theme.dispose();
    settings.dispose();
    directory.deleteSync(recursive: true);
  });
}
