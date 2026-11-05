import 'youtube_video.dart';

enum OnlineVideoProvider { youtube, vimeo, googleDrive, dropbox, oneDrive, box }

/// Converts provider share pages into playable targets without changing the
/// original link saved in the document (including private sharing tokens).
class OnlineVideo {
  const OnlineVideo({
    required this.provider,
    required this.source,
    this.embedUri,
    this.thumbnailUri,
    this.metadataUri,
    this.mediaUri,
  });

  final OnlineVideoProvider provider;
  final Uri source;
  final Uri? embedUri;
  final Uri? thumbnailUri;
  final Uri? metadataUri;
  final Uri? mediaUri;

  String get label => switch (provider) {
    OnlineVideoProvider.youtube => 'YouTube',
    OnlineVideoProvider.vimeo => 'Vimeo',
    OnlineVideoProvider.googleDrive => 'Google Drive',
    OnlineVideoProvider.dropbox => 'Dropbox',
    OnlineVideoProvider.oneDrive => 'OneDrive',
    OnlineVideoProvider.box => 'Box',
  };

  static OnlineVideo? parse(String? value) {
    final uri = Uri.tryParse(value?.trim() ?? '');
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty) {
      return null;
    }
    final youtube = YoutubeVideo.parse(value);
    if (youtube != null) {
      return OnlineVideo(
        provider: OnlineVideoProvider.youtube,
        source: uri,
        embedUri: youtube.embedUri,
        thumbnailUri: youtube.thumbnailUri,
      );
    }
    final host = uri.host.toLowerCase();
    final parts = uri.pathSegments;
    if (const {
      'vimeo.com',
      'www.vimeo.com',
      'player.vimeo.com',
    }.contains(host)) {
      String? id;
      String? hash = uri.queryParameters['h'];
      if (host == 'player.vimeo.com') {
        if (parts.length == 2 && parts.first == 'video') id = parts[1];
      } else {
        // Unlisted hashes may themselves be numeric; the first segment is
        // always the video ID in the ordinary /ID/HASH share format.
        if (parts.isNotEmpty && RegExp(r'^\d+$').hasMatch(parts.first)) {
          if (parts.length <= 2) {
            id = parts.first;
            if (parts.length == 2) hash ??= parts[1];
          }
        } else if ((parts.length == 3 && parts.first == 'channels') ||
            (parts.length == 4 &&
                parts.first == 'groups' &&
                parts[2] == 'videos') ||
            (parts.length == 4 &&
                parts.first == 'showcase' &&
                parts[2] == 'video')) {
          id = parts.last;
        }
      }
      if (id == null || !RegExp(r'^\d+$').hasMatch(id)) return null;
      return OnlineVideo(
        provider: OnlineVideoProvider.vimeo,
        source: uri,
        embedUri: Uri.https('player.vimeo.com', '/video/$id', {'h': ?hash}),
        metadataUri: Uri.https('vimeo.com', '/api/oembed.json', {
          'url': uri.toString(),
        }),
      );
    }
    if (host == 'drive.google.com') {
      String? id;
      final fileIndex = parts.indexOf('d');
      if (parts.isNotEmpty &&
          parts.first == 'file' &&
          fileIndex >= 0 &&
          fileIndex + 1 < parts.length) {
        id = parts[fileIndex + 1];
      } else if (const {'/open', '/uc'}.contains(uri.path)) {
        id = uri.queryParameters['id'];
      }
      if (id == null || !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id)) return null;
      final access = {
        if (uri.queryParameters['resourcekey'] case final String key)
          'resourcekey': key,
      };
      return OnlineVideo(
        provider: OnlineVideoProvider.googleDrive,
        source: uri,
        embedUri: Uri.https(host, '/file/d/$id/preview', access),
        thumbnailUri: Uri.https(host, '/thumbnail', {
          'id': id,
          'sz': 'w720',
          ...access,
        }),
      );
    }
    if (const {'dropbox.com', 'www.dropbox.com'}.contains(host) &&
        (uri.path.startsWith('/s/') || uri.path.startsWith('/scl/fi/'))) {
      final query = Map<String, String>.of(uri.queryParameters)..remove('dl');
      query['raw'] = '1';
      final raw = uri.replace(queryParameters: query);
      return OnlineVideo(
        provider: OnlineVideoProvider.dropbox,
        source: uri,
        embedUri: raw,
        mediaUri: raw,
        metadataUri: uri,
      );
    }
    if (host == '1drv.ms' ||
        host == 'onedrive.live.com' ||
        host.endsWith('.sharepoint.com')) {
      // These links often require the browser's authenticated session. Keep the
      // original share URL instead of inventing a download or embed URL.
      return OnlineVideo(
        provider: OnlineVideoProvider.oneDrive,
        source: uri,
        metadataUri: uri,
      );
    }
    if ((host == 'box.com' || host.endsWith('.box.com')) &&
        uri.path.startsWith('/s/')) {
      return OnlineVideo(
        provider: OnlineVideoProvider.box,
        source: uri,
        metadataUri: uri,
      );
    }
    return null;
  }
}
