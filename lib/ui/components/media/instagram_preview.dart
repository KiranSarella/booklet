import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:html/parser.dart' as html;

import 'online_video.dart';

class InstagramPreview {
  const InstagramPreview({this.title, this.thumbnail});

  final String? title;
  final Uri? thumbnail;
  static final _pending = <String, Future<InstagramPreview?>>{};

  static InstagramPreview parse(String body, Uri source) {
    final document = html.parse(body);
    // Select the post image, never an avatar, recommendation, or login logo.
    final image = document.querySelector('img.EmbeddedMediaImage');
    String? imageUrl = image?.attributes['src'];
    String? title;
    final caption = document.querySelector('.Caption')?.clone(true);
    if (caption != null) {
      for (final extra in caption.querySelectorAll(
        '.CaptionUsername, .CaptionComments, .CaptionCommentsExpand',
      )) {
        extra.remove();
      }
      title = caption.text.trim();
    }
    if (title == null || title.isEmpty) {
      for (final key in ['og:title', 'og:description']) {
        final value = document
            .querySelector('meta[property="$key"]')
            ?.attributes['content']
            ?.trim();
        if (value != null &&
            value.isNotEmpty &&
            value.toLowerCase() != 'instagram') {
          title = value;
          break;
        }
      }
    }
    // Only accept OG images when this page identifies an actual post.
    if (imageUrl == null && title != null && title.isNotEmpty) {
      imageUrl = document
          .querySelector('meta[property="og:image"]')
          ?.attributes['content'];
    }
    final uri = imageUrl == null ? null : source.resolve(imageUrl);
    return InstagramPreview(
      title: title == null || title.isEmpty
          ? null
          : title.replaceAll(RegExp(r'\s+'), ' '),
      thumbnail: uri != null && const {'http', 'https'}.contains(uri.scheme)
          ? uri
          : null,
    );
  }

  static Future<InstagramPreview?> load(OnlineVideo video) async {
    final key = video.metadataUri.toString();
    if (_pending.length >= 32 && !_pending.containsKey(key)) {
      _pending.remove(_pending.keys.first);
    }
    final result = await _pending.putIfAbsent(key, () async {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);
      try {
        final request = await client
            .getUrl(video.metadataUri!)
            .timeout(const Duration(seconds: 15));
        final response = await request.close().timeout(
          const Duration(seconds: 15),
        );
        if (response.statusCode != HttpStatus.ok ||
            response.headers.contentType?.mimeType != 'text/html') {
          return null;
        }
        final bytes = BytesBuilder();
        await for (final chunk in response.timeout(
          const Duration(seconds: 15),
        )) {
          bytes.add(chunk);
          if (bytes.length > 5 * 1024 * 1024) return null;
        }
        return parse(
          utf8.decode(bytes.takeBytes(), allowMalformed: true),
          video.source,
        );
      } catch (_) {
        return null;
      } finally {
        client.close(force: true);
      }
    });
    if (result == null || (result.title == null && result.thumbnail == null)) {
      _pending.remove(key);
    }
    return result;
  }
}
