import 'dart:convert';
import 'dart:io';

import 'package:booklet/business/page_content.dart';
import 'package:booklet/storage/booklet_file.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/image_component.dart';
import 'package:booklet/ui/components/inbuilt_components.dart';
import 'package:booklet/ui/editor_themes/editor_themes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('BookletFile component persistence', () {
    test('persists and restores the same text component ID', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'booklet_component_test',
      );
      final packagePath = '${tempDir.path}/test_booklet';
      const componentId = 'text-component-id';
      final page = PageContent(
        id: 'page-1',
        title: 'Test page',
        components: [
          ComponentBox(
            component: InbuiltComponents.prepareCompoent(componentId, 'text'),
          ),
        ],
      );

      await BookletFile.savePage(packagePath, page);
      final savedPageJson = jsonDecode(
        await File('$packagePath/pages/page-1.json').readAsString(),
      ) as Map<String, dynamic>;
      final savedComponent =
          savedPageJson['components'][0] as Map<String, dynamic>;

      expect(savedComponent['id'], componentId);

      final loadedPage = await BookletFile.loadPage(
        packagePath,
        'page-1',
        EditorTheme(),
      );
      expect(loadedPage.components.single.component.id, componentId);

      final loadedAgain = await BookletFile.loadPage(
        packagePath,
        'page-1',
        EditorTheme(),
      );
      expect(loadedAgain.components.single.component.id, componentId);

      page.dispose();
      loadedPage.dispose();
      loadedAgain.dispose();
      await tempDir.delete(recursive: true);
    });
  });

  group('BookletFile image persistence', () {
    test('copies image to media folder and stores size metadata', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'booklet_image_test',
      );
      final packagePath = '${tempDir.path}/test_booklet';
      final sourceFile = File('${tempDir.path}/source.png');
      await sourceFile.writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10]);

      final image = ImageComponent(id: 'image-1', mediaPath: sourceFile.path);
      image.state.width = 640;
      image.state.height = 480;

      final page = PageContent(
        id: 'page-1',
        title: 'Test page',
        components: [ComponentBox(component: image)],
      );

      await BookletFile.savePage(packagePath, page);

      final savedPageJson = jsonDecode(
        await File('$packagePath/pages/page-1.json').readAsString(),
      ) as Map<String, dynamic>;
      final savedImage = savedPageJson['components'][0] as Map<String, dynamic>;

      expect(savedImage['mediaPath'], isNotNull);
      expect(savedImage['mediaPath'], startsWith('media/'));
      expect(savedImage['mediaPath'], endsWith('.png'));
      expect(
        File('$packagePath/${savedImage['mediaPath']}').existsSync(),
        isTrue,
      );
      expect(savedImage['width'], 640);
      expect(savedImage['height'], 480);

      await BookletFile.savePage(packagePath, page);

      final resavedPageJson = jsonDecode(
        await File('$packagePath/pages/page-1.json').readAsString(),
      ) as Map<String, dynamic>;
      final resavedImage =
          resavedPageJson['components'][0] as Map<String, dynamic>;
      final mediaFiles = await Directory('$packagePath/media').list().toList();

      expect(resavedImage['mediaPath'], savedImage['mediaPath']);
      expect(mediaFiles, hasLength(1));

      page.dispose();
      await tempDir.delete(recursive: true);
    });
  });
}
