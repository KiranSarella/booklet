import 'package:flutter_svg/flutter_svg.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/icon_component.dart';
import 'package:booklet/ui/components/statistical_chart/statistical_chart_document.dart';
import 'package:booklet/ui/components/statistical_chart/statistical_chart_editor.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/statistical_chart_component.dart';

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
  testWidgets('icon miniature renders SVG and updates styling without editor controls', (tester) async {
    final component = IconComponent(id: 'icon');
    final state = component.state;
    state.setIcon(Uint8List.fromList(utf8.encode(
      '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><rect width="32" height="32"/></svg>',
    )), 'svg');
    final box = ComponentBox(component: component);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(
      width: 150, height: 30, child: ComponentMinimapPreview(box: box),
    ))));
    await tester.pumpAndSettle();
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byType(IconButton), findsNothing);
    state.setTint(Colors.red);
    state.setImageFit(IconImageFit.fill);
    state.setShape(IconShape.circle);
    state.setBorderEnabled(true);
    await tester.pumpAndSettle();
    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(svg.fit, BoxFit.cover);
    expect(svg.colorFilter, const ColorFilter.mode(Colors.red, BlendMode.srcIn));
    expect(tester.widget<ClipRRect>(find.byType(ClipRRect)).borderRadius,
      BorderRadius.circular(32));
    expect(tester.takeException(), isNull);
    state.removeIcon();
    await tester.pumpAndSettle();
    expect(find.byType(SvgPicture), findsNothing);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    component.dispose();
  });

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
    expect(
      find.byIcon(Icons.integration_instructions_outlined),
      findsOneWidget,
    );
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

  testWidgets('compressed headings paint entirely inside their preview', (
    tester,
  ) async {
    final settings = DocumentSettingsController();
    final theme = PageSettingsController(settings);
    final controller = EditorController(theme, settings);
    for (final kind in ['title', 'heading', 'subheading', 'inline_heading']) {
      final box = controller.viewModel.createComponentBelowType(0, kind);
      (box.component.state as TextComponentState).controller.document.insert(
        0,
        'A long heading that must fit in the minimap',
      );
      for (final height in [3.0, 6.0, 12.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: 150,
                height: height,
                child: ComponentMinimapPreview(box: box),
              ),
            ),
          ),
        );
        final preview = tester.renderObject<RenderBox>(
          find.byType(ComponentMinimapPreview),
        );
        final text = tester.renderObject<RenderBox>(
          find.text('A long heading that must fit in the minimap'),
        );
        final painted = MatrixUtils.transformRect(
          text.getTransformTo(preview),
          Offset.zero & text.size,
        );
        expect(painted.top, greaterThanOrEqualTo(-0.001));
        expect(painted.bottom, lessThanOrEqualTo(height + 0.001));
        expect(painted.left, greaterThanOrEqualTo(-0.001));
        expect(painted.right, lessThanOrEqualTo(150.001));
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    theme.dispose();
    settings.dispose();
  });

  testWidgets('chart miniatures show actual charts and fit compressed rows', (
    tester,
  ) async {
    final component = StatisticalChartComponent(id: 'miniature');
    final box = ComponentBox(component: component);
    for (final type in [
      ChartType.column,
      ChartType.pie,
      ChartType.bubble,
      ChartType.stackedBar,
    ]) {
      component.state.restore({
        'datasetFormat': type == ChartType.bubble ? 'xy' : 'categorical',
        'graphType': type.name,
        'title': 'Chart title',
        if (type == ChartType.bubble)
          'xValues': [1, 2, 3]
        else
          'labels': ['A', 'B', 'C'],
        'values': [3, 7, 5],
        if (type == ChartType.bubble) 'sizes': [1, 4, 9],
        if (type == ChartType.stackedBar)
          'series': [
            {
              'name': 'Second',
              'values': [2, 4, 1],
            },
          ],
      });
      for (final height in [3.0, 30.0, 80.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: 150,
                height: height,
                child: ComponentMinimapPreview(box: box),
              ),
            ),
          ),
        );
        final chart = tester.widget<StatisticalChartPreview>(
          find.byType(StatisticalChartPreview),
        );
        expect(chart.state, same(component.state));
        expect(chart.state.type, type);
        expect(find.byIcon(Icons.bar_chart), findsNothing);
        expect(find.byType(StatisticalChartEditor), findsNothing);
        expect(find.byType(TextField), findsNothing);
        final root = tester.renderObject<RenderBox>(
          find.byType(ComponentMinimapPreview),
        );
        final miniature = tester.renderObject<RenderBox>(
          find.byType(StatisticalChartPreview),
        );
        final painted = MatrixUtils.transformRect(
          miniature.getTransformTo(root),
          Offset.zero & miniature.size,
        );
        expect(painted.top, greaterThanOrEqualTo(-.001));
        expect(painted.bottom, lessThanOrEqualTo(height + .001));
        expect(painted.left, greaterThanOrEqualTo(-.001));
        expect(painted.right, lessThanOrEqualTo(150.001));
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox());
    component.dispose();
  });
  testWidgets('chart miniatures update after saved edits without remounting', (
    tester,
  ) async {
    final component = StatisticalChartComponent(id: 'live-miniature');
    final box = ComponentBox(component: component);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 150,
          height: 80,
          child: ComponentMinimapPreview(box: box),
        ),
      ),
    );
    expect(find.text('A: Value 3.0'), findsOneWidget);
    component.state.restore({
      'graphType': 'pie',
      'title': 'Updated',
      'labels': ['Edited'],
      'values': [42],
    });
    await tester.pump();
    expect(find.text('Updated'), findsOneWidget);
    expect(find.text('Edited: Value 42.0'), findsOneWidget);
    expect(find.text('A: Value 3.0'), findsNothing);
    expect(
      tester
          .widget<StatisticalChartPreview>(find.byType(StatisticalChartPreview))
          .state
          .type,
      ChartType.pie,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    component.dispose();
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
    const cacheChannel = MethodChannel('plugins.flutter.io/path_provider');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      cacheChannel,
      (_) async => directory.path,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        cacheChannel,
        null,
      ),
    );
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
