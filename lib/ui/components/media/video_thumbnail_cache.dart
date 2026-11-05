import 'online_video.dart';
import 'online_video_thumbnail.dart';

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// Shared disk cache for component and minimap previews.
class VideoThumbnailCache {
  static final _pending = <String, Future<Uint8List?>>{};

  static Future<Uint8List?> load(String? source) async {
    if (source == null || source.isEmpty) return null;
    final online = OnlineVideo.parse(source);
    var key = source;
    final uri = Uri.tryParse(source);
    if (uri?.scheme != 'http' && uri?.scheme != 'https') {
      try {
        final stat = await File(source).stat();
        key = '$source:${stat.size}:${stat.modified.millisecondsSinceEpoch}';
      } catch (_) {
        return null;
      }
    }
    final cacheKey = const Uuid().v5(Namespace.url.value, key);
    return _pending.putIfAbsent(cacheKey, () async {
      try {
        final directory = await getApplicationCacheDirectory();
        final file = File('${directory.path}/video_thumbnails/$cacheKey.png');
        if (await file.exists()) return await file.readAsBytes();
        await file.parent.create(recursive: true);
        Uint8List? bytes;
        if (online != null) {
          bytes = await OnlineVideoThumbnail.load(online);
        }
        // Dropbox raw links can still yield a frame when public page metadata
        // has no image. Never try to decode a provider's HTML share page.
        final mediaSource = online?.mediaUri?.toString() ?? source;
        if (bytes == null && (online == null || online.mediaUri != null)) {
          if (Platform.isMacOS) {
            await const MethodChannel('booklet/video_thumbnail')
                .invokeMethod<bool>('createVideoThumbnail', {
                  'videoPath': mediaSource,
                  'thumbnailPath': file.path,
                });
            if (await file.exists()) bytes = await file.readAsBytes();
          } else {
            bytes = await VideoThumbnail.thumbnailData(
              video: mediaSource,
              imageFormat: ImageFormat.PNG,
              maxWidth: 720,
              quality: 75,
            );
          }
        }
        if (bytes != null) await file.writeAsBytes(bytes, flush: true);
        return bytes;
      } catch (_) {
        // Thumbnail failure must not prevent video playback.
        return null;
      } finally {
        _pending.remove(cacheKey);
      }
    });
  }
}
