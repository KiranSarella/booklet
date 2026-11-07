import 'package:booklet/business/booklet_asset.dart';
import 'package:booklet/ui/components/media/instagram_preview.dart';
import 'package:booklet/ui/components/media/online_video.dart';
import 'package:booklet/ui/components/media/online_video_thumbnail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const source = 'https://www.instagram.com/reels/DcJfWVNtLzJ/';
  test(
    'recognizes Instagram post formats and preserves sharing parameters',
    () {
      for (final path in ['reels', 'reel', 'p', 'tv']) {
        final url = 'https://www.instagram.com/$path/DcJfWVNtLzJ/?igsh=token';
        final video = OnlineVideo.parse(url)!;
        expect(video.provider, OnlineVideoProvider.instagram);
        expect(video.source.toString(), url);
        expect(
          video.metadataUri.toString(),
          'https://www.instagram.com/p/DcJfWVNtLzJ/embed/captioned/',
        );
        expect(video.embedUri, isNull);
        expect(
          const BookletAsset(id: '1', name: 'My saved Reel', path: source).kind,
          BookletAssetKind.video,
        );
      }
      expect(
        OnlineVideo.parse('https://instagram.com/accounts/login/'),
        isNull,
      );
      expect(
        OnlineVideo.parse('https://instagram.com.evil.test/reel/DcJfWVNtLzJ/'),
        isNull,
      );
    },
  );

  test('extracts post image and caption without avatar or comments', () {
    const body = '''<img src="https://example.com/avatar.jpg">
      <img class="EmbeddedMediaImage" src="https://example.com/reel.jpg?a=1&amp;b=2">
      <div class="Caption"><a class="CaptionUsername">creator</a>Exercise &amp; training
      <div class="CaptionComments">irrelevant comment</div></div>''';
    final result = InstagramPreview.parse(body, Uri.parse(source));
    expect(result.title, 'Exercise & training');
    expect(result.thumbnail.toString(), 'https://example.com/reel.jpg?a=1&b=2');
    expect(
      OnlineVideoThumbnail.metadataImage(OnlineVideo.parse(source)!, body),
      result.thumbnail,
    );
  });

  test('rejects generic Instagram login metadata', () {
    final result = InstagramPreview.parse(
      '''<meta property="og:title" content="Instagram">
      <meta property="og:image" content="https://example.com/logo.png">''',
      Uri.parse(source),
    );
    expect(result.title, isNull);
    expect(result.thumbnail, isNull);
  });

  test(
    'supports public post Open Graph metadata and rejects non-web images',
    () {
      final result = InstagramPreview.parse(
        '''<meta property="og:title" content="Creator: A reel">
      <meta property="og:image" content="https://example.com/thumb.jpg">''',
        Uri.parse(source),
      );
      expect(result.title, 'Creator: A reel');
      expect(result.thumbnail.toString(), 'https://example.com/thumb.jpg');
      expect(
        InstagramPreview.parse(
          '<img class="EmbeddedMediaImage" src="javascript:bad">',
          Uri.parse(source),
        ).thumbnail,
        isNull,
      );
    },
  );
}
