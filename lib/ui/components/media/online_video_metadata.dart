import 'dart:convert';
import 'dart:io';

import 'online_video.dart';

/// Public titles for providers that expose oEmbed metadata.
class OnlineVideoMetadata {
  static Uri? endpoint(OnlineVideo video) => switch (video.provider) {
    OnlineVideoProvider.youtube => Uri.https('www.youtube.com', '/oembed', {
      'url': video.source.toString(),
      'format': 'json',
    }),
    OnlineVideoProvider.vimeo => video.metadataUri,
    _ => null,
  };

  static String? titleFromJson(String body) {
    final data = jsonDecode(body);
    final title = data is Map ? data['title'] : null;
    return title is String && title.trim().isNotEmpty ? title.trim() : null;
  }

  static Future<String?> loadTitle(OnlineVideo video) async {
    final uri = endpoint(video);
    if (uri == null) return null;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 10));
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      if (response.statusCode != HttpStatus.ok) return null;
      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 10));
      return titleFromJson(body);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
