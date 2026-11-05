import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Content-addressed previews survive document saves and model-file moves.
class Model3dThumbnailCache {
  static Future<File> _file(String source) async {
    final bytes = await File(source).readAsBytes();
    final key = const Uuid().v5(Namespace.url.value, base64Encode(bytes));
    final directory = await getApplicationCacheDirectory();
    return File('${directory.path}/model_3d_thumbnails/v1-$key.png');
  }

  static Future<Uint8List?> load(String source) async {
    try {
      final file = await _file(source);
      return await file.exists() ? await file.readAsBytes() : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(String source, Uint8List bytes) async {
    try {
      final file = await _file(source);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {
      // Cache failures must not prevent viewing the model.
    }
  }
}
