import 'package:html/parser.dart' as html_parser;

import 'online_video.dart';
import '../inbuilt_components/component_defs/embed_component.dart';

/// Resolve provider markup to a remote target without executing pasted scripts.
class AssetEmbed {
  const AssetEmbed({required this.source, required this.title, this.html});
  final Uri source;
  final String title;
  final String? html;

  static AssetEmbed? parse(String code) {
    final document = html_parser.parse(code);
    final frame = document.querySelector('iframe[src]');
    if (frame != null) {
      var src = frame.attributes['src']!.trim();
      if (src.startsWith('//')) src = 'https:$src';
      final uri = Uri.tryParse(src);
      if (!_remote(uri)) return null;
      return AssetEmbed(
        source: uri!,
        title: frame.attributes['title']?.trim().isNotEmpty == true
            ? frame.attributes['title']!.trim()
            : '${uri.host} embed',
      );
    }
    final instagram = document.querySelector('blockquote.instagram-media');
    if (instagram != null) {
      final links = [
        instagram.attributes['data-instgrm-permalink'],
        ...instagram
            .querySelectorAll('a[href]')
            .map((a) => a.attributes['href']),
      ];
      for (final link in links) {
        final video = OnlineVideo.parse(link);
        if (video?.provider == OnlineVideoProvider.instagram) {
          return AssetEmbed(source: video!.source, title: 'Instagram post');
        }
      }
    }
    final target = EmbedContentParser.parse(code);
    if (target?.provider == EmbedProvider.x) {
      final link = html_parser
          .parse(target!.html)
          .querySelector('a[href]')!
          .attributes['href']!;
      return AssetEmbed(
        source: Uri.parse(link),
        title: 'X post',
        html: target.html,
      );
    }
    return null;
  }

  static bool _remote(Uri? uri) =>
      uri != null &&
      const {'https', 'http'}.contains(uri.scheme) &&
      uri.host.isNotEmpty;

  Uri get displayUri {
    final online = OnlineVideo.parse(source.toString());
    if (online?.provider == OnlineVideoProvider.instagram) {
      return online!.metadataUri!;
    }
    return source;
  }
}
