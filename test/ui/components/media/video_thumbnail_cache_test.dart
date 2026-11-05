import 'dart:io';

import 'package:booklet/ui/components/media/video_thumbnail_cache.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'reuses cached thumbnail on disk without calling generator again',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'video_cache_test_',
      );
      final source = File('${directory.path}/lesson.mp4');
      await source.writeAsBytes([1, 2, 3]);
      final bytes = Uint8List.fromList([10, 20, 30]);
      var requests = 0;
      const cacheChannel = MethodChannel('plugins.flutter.io/path_provider');
      const native = MethodChannel('booklet/video_thumbnail');
      const plugin = MethodChannel('plugins.justsoft.xyz/video_thumbnail');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        cacheChannel,
        (_) async => directory.path,
      );
      messenger.setMockMethodCallHandler(native, (call) async {
        requests++;
        await File((call.arguments as Map)['thumbnailPath'] as String)
            .writeAsBytes(bytes);
        return true;
      });
      messenger.setMockMethodCallHandler(plugin, (_) async {
        requests++;
        return bytes;
      });
      addTearDown(() async {
        messenger.setMockMethodCallHandler(cacheChannel, null);
        messenger.setMockMethodCallHandler(native, null);
        messenger.setMockMethodCallHandler(plugin, null);
        await directory.delete(recursive: true);
      });
      expect(await VideoThumbnailCache.load(source.path), bytes);
      expect(await VideoThumbnailCache.load(source.path), bytes);
      expect(requests, 1);
      // Replacing a local video invalidates its cached preview.
      await source.writeAsBytes([1, 2, 3, 4]);
      expect(await VideoThumbnailCache.load(source.path), bytes);
      expect(requests, 2);
    },
  );
}
