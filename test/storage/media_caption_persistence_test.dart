import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';

import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/business/page_content.dart';
import 'package:booklet/storage/booklet_file.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_snapshot.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/image_component.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/video_component.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'image and video captions survive save/load and independent copy/paste',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'caption_persistence_',
      );
      final settings = DocumentSettingsController();
      final theme = PageSettingsController(settings);
      final image = ImageComponent(
        id: 'image',
        mediaPath: 'https://example.com/photo.jpg',
      );
      final video = VideoComponent(
        id: 'video',
        mediaPath: 'https://vimeo.com/123456789',
      );
      image.state.caption = 'Image caption\nSecond line';
      video.state.caption = 'Video caption\nSecond line';
      final page = PageContent(
        id: 'captions',
        title: 'Captions',
        components: [
          ComponentBox(component: image),
          ComponentBox(component: video),
        ],
      );
      addTearDown(() async {
        page.dispose();
        theme.dispose();
        settings.dispose();
        await directory.delete(recursive: true);
      });
      for (final box in page.components) {
        final copy = ComponentSnapshot.capture(box).instantiate();
        final original = box.component.state as CaptionedMediaComponentState;
        final copied = copy.component.state as CaptionedMediaComponentState;
        expect(copied.caption, original.caption);
        copied.caption = 'Edited copy';
        expect(original.caption, isNot('Edited copy'));
        copy.component.dispose();
      }
      await BookletFile.savePage(directory.path, page);
      final loaded = await BookletFile.loadPage(directory.path, page.id, theme);
      expect(
        (loaded.components[0].component.state as ImageComponentState).caption,
        image.state.caption,
      );
      expect(
        (loaded.components[1].component.state as VideoComponentState).caption,
        video.state.caption,
      );
      loaded.dispose();
      // Older pages without the new field still load with an empty caption.
      final file = File('${directory.path}/pages/${page.id}.json');
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      for (final component in json['components'] as List) {
        (component as Map).remove('caption');
      }
      await file.writeAsString(jsonEncode(json));
      final legacy = await BookletFile.loadPage(directory.path, page.id, theme);
      for (final box in legacy.components) {
        expect(
          (box.component.state as CaptionedMediaComponentState).caption,
          isEmpty,
        );
      }
      legacy.dispose();
    },
  );
}
