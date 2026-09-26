import 'dart:convert';
import 'dart:io';

import 'package:booklet/business/page_content.dart';
import 'package:booklet/storage/booklet_file.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/image_component.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BookletFile image persistence', () {
    test('copies image to media folder and stores size metadata', () async {
      final tempDir = await Directory.systemTemp.createTemp('booklet_image_test');
      final packagePath = '${tempDir.path}/test_booklet';
      final sourceFile = File('${tempDir.path}/source.png');
      await sourceFile.writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10]);

      final image = ImageComponent(id: 'image-1', mediaPath: sourceFile.path);
      image.state.width = 640;
      image.state.height = 480;

      final page = PageContent(
        id: 'page-1',
        title: 'Test page',
        components: [
          ComponentBox(component: image),
        ],
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

      page.dispose();
      await tempDir.delete(recursive: true);
    });
  });
}
