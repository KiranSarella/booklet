import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:html/parser.dart' as html;

import 'online_video.dart';
import 'instagram_preview.dart';

/// Best-effort public metadata only. Restricted files retain a provider card.
class OnlineVideoThumbnail {
  static Future<Uint8List?> load(OnlineVideo video) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      var image = video.provider == OnlineVideoProvider.instagram
          ? (await InstagramPreview.load(video))?.thumbnail
          : video.thumbnailUri;
      if (image == null &&
          video.metadataUri != null &&
          video.provider != OnlineVideoProvider.instagram) {
        final data = await _get(client, video.metadataUri!, image: false);
        if (data != null) {
          final text = utf8.decode(data, allowMalformed: true);
          image = metadataImage(video, text);
        }
      }
      return image == null ? null : await _get(client, image, image: true);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static Uri? metadataImage(OnlineVideo video, String body) {
    if (video.provider == OnlineVideoProvider.instagram) {
      return InstagramPreview.parse(body, video.source).thumbnail;
    }
    String? url;
    if (video.provider == OnlineVideoProvider.vimeo) {
      final data = jsonDecode(body);
      if (data is Map && data['thumbnail_url'] is String) {
        url = data['thumbnail_url'];
      }
    } else {
      final document = html.parse(body);
      for (final meta in document.querySelectorAll('meta')) {
        final name = meta.attributes['property'] ?? meta.attributes['name'];
        if (name == 'og:image' || name == 'twitter:image') {
          url = meta.attributes['content'];
          if (url != null && url.isNotEmpty) break;
        }
      }
    }
    if (url == null || url.isEmpty) return null;
    final uri = video.source.resolve(url);
    return uri.scheme == 'https' || uri.scheme == 'http' ? uri : null;
  }

  static Future<Uint8List?> _get(
    HttpClient client,
    Uri uri, {
    required bool image,
  }) async {
    final request = await client
        .getUrl(uri)
        .timeout(const Duration(seconds: 15));
    final response = await request.close().timeout(const Duration(seconds: 15));
    if (response.statusCode != HttpStatus.ok) return null;
    final type = response.headers.contentType?.mimeType ?? '';
    if (image && !type.startsWith('image/')) return null;
    if (!image && type != 'text/html' && type != 'application/json') {
      return null;
    }
    final bytes = BytesBuilder();
    await for (final chunk in response.timeout(const Duration(seconds: 15))) {
      bytes.add(chunk);
      if (bytes.length > 5 * 1024 * 1024) return null;
    }
    return bytes.isEmpty ? null : bytes.takeBytes();
  }
}
