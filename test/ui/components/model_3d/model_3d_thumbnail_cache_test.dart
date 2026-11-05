import 'dart:io';

import 'package:booklet/ui/components/model_3d/model_3d_thumbnail_cache.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'preview survives file moves and invalidates when model content changes',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'model_preview_test',
      );
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) async => directory.path);
      addTearDown(() async {
        messenger.setMockMethodCallHandler(channel, null);
        await directory.delete(recursive: true);
      });
      final source = File('${directory.path}/model.glb');
      await source.writeAsBytes([1, 2, 3]);
      final image = Uint8List.fromList([10, 20, 30]);
      expect(await Model3dThumbnailCache.load(source.path), isNull);
      await Model3dThumbnailCache.save(source.path, image);
      expect(await Model3dThumbnailCache.load(source.path), image);
      final moved = await source.copy('${directory.path}/saved-model.glb');
      await source.delete();
      expect(await Model3dThumbnailCache.load(moved.path), image);
      await moved.writeAsBytes([1, 2, 3, 4]);
      expect(await Model3dThumbnailCache.load(moved.path), isNull);
    },
  );
}
