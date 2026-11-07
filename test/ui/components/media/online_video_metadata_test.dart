import 'package:booklet/business/booklet_asset.dart';
import 'package:booklet/ui/components/media/online_video.dart';
import 'package:booklet/ui/components/media/online_video_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('YouTube links override an image extension or a renamed asset', () {
    for (final name in ['watch.png', 'My saved video', 'watch.mp4']) {
      final asset = BookletAsset(
        id: 'video',
        name: name,
        path: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );
      expect(asset.kind, BookletAssetKind.video);
      expect(
        BookletAsset.fromJson(asset.toJson()).kind,
        BookletAssetKind.video,
      );
    }
  });

  test('YouTube metadata endpoint preserves the original video URL', () {
    const source = 'https://youtu.be/dQw4w9WgXcQ?t=42';
    final endpoint = OnlineVideoMetadata.endpoint(OnlineVideo.parse(source)!);
    expect(endpoint!.host, 'www.youtube.com');
    expect(endpoint.path, '/oembed');
    expect(endpoint.queryParameters['url'], source);
  });

  test('uses a nonempty public title', () {
    expect(
      OnlineVideoMetadata.titleFromJson('{"title":"  A video title  "}'),
      'A video title',
    );
    expect(OnlineVideoMetadata.titleFromJson('{"title":" "}'), isNull);
    expect(
      OnlineVideoMetadata.titleFromJson('{"error":"Unavailable"}'),
      isNull,
    );
  });
}
