/// A supported YouTube URL, separated from direct media file URLs.
class YoutubeVideo {
  const YoutubeVideo(this.id, {this.startSeconds = 0});

  final String id;
  final int startSeconds;

  // Matches the installed application's identifier in the platform manifests.
  static const appOrigin = 'https://com.example.booklet';

  Uri get embedUri => Uri.https('www.youtube-nocookie.com', '/embed/$id', {
    'playsinline': '1',
    'origin': appOrigin,
    if (startSeconds > 0) 'start': '$startSeconds',
  });

  Uri get thumbnailUri => Uri.https('img.youtube.com', '/vi/$id/hqdefault.jpg');

  static YoutubeVideo? parse(String? source) {
    final uri = Uri.tryParse(source?.trim() ?? '');
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      return null;
    }
    final host = uri.host.toLowerCase();
    final segments = uri.pathSegments;
    String? id;
    if (host == 'youtu.be' || host == 'www.youtu.be') {
      if (segments.length == 1) id = segments.first;
    } else if (const {
      'youtube.com',
      'www.youtube.com',
      'm.youtube.com',
      'music.youtube.com',
      'youtube-nocookie.com',
      'www.youtube-nocookie.com',
    }.contains(host)) {
      if (uri.path == '/watch') {
        id = uri.queryParameters['v'];
      } else if (segments.length == 2 &&
          const {'embed', 'shorts', 'live'}.contains(segments.first)) {
        id = segments[1];
      }
    }
    if (id == null || !RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(id)) return null;
    final time = uri.queryParameters['t'] ?? uri.queryParameters['start'] ?? '';
    var seconds = int.tryParse(time) ?? 0;
    if (seconds == 0 &&
        RegExp(r'^(?:\d+h)?(?:\d+m)?(?:\d+s)?$').hasMatch(time)) {
      for (final match in RegExp(r'(\d+)([hms])').allMatches(time)) {
        seconds +=
            int.parse(match[1]!) *
            switch (match[2]) {
              'h' => 3600,
              'm' => 60,
              _ => 1,
            };
      }
    }
    return YoutubeVideo(id, startSeconds: seconds < 0 ? 0 : seconds);
  }
}
