import 'package:flutter/services.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/video_component.dart';
import 'package:booklet/ui/components/media/online_video.dart';
import 'package:booklet/ui/components/media/online_video_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Vimeo unlisted hash is preserved in player and oEmbed request', () {
    const source = 'https://vimeo.com/123456789/secretHash';
    final video = OnlineVideo.parse(source)!;
    expect(
      video.embedUri.toString(),
      'https://player.vimeo.com/video/123456789?h=secretHash',
    );
    expect(video.metadataUri!.queryParameters['url'], source);
    expect(
      OnlineVideo.parse('https://player.vimeo.com/video/123456789?h=secret')!
          .embedUri!
          .queryParameters['h'],
      'secret',
    );
    expect(
      OnlineVideo.parse('https://vimeo.com/channels/staffpicks/123456789')!
          .embedUri!
          .path,
      '/video/123456789',
    );
  });
  test('Drive preview and thumbnail retain resource key for shared files', () {
    for (final url in [
      'https://drive.google.com/file/d/file_ID-123/view?resourcekey=secret',
      'https://drive.google.com/open?id=file_ID-123&resourcekey=secret',
    ]) {
      final video = OnlineVideo.parse(url)!;
      expect(video.embedUri!.path, '/file/d/file_ID-123/preview');
      expect(video.embedUri!.queryParameters['resourcekey'], 'secret');
      expect(video.thumbnailUri!.queryParameters['resourcekey'], 'secret');
      expect(video.source.toString(), url);
    }
    expect(
      OnlineVideo.parse('https://drive.google.com/drive/folders/abc'),
      isNull,
    );
  });
  test('Dropbox raw view retains access token and original browser URL', () {
    const url =
        'https://www.dropbox.com/scl/fi/abc/lesson.mp4?rlkey=secret&dl=0';
    final video = OnlineVideo.parse(url)!;
    expect(video.embedUri!.queryParameters, {'rlkey': 'secret', 'raw': '1'});
    expect(video.source.toString(), url);
  });
  test('OneDrive and Box use original browser URLs without guessed embeds', () {
    for (final url in [
      'https://1drv.ms/v/s!Abc?e=secret',
      'https://onedrive.live.com/?id=abc&authkey=secret',
      'https://company.sharepoint.com/:v:/s/lessons/abc',
      'https://app.box.com/s/abc',
    ]) {
      final video = OnlineVideo.parse(url)!;
      expect(video.embedUri, isNull);
      expect(video.source.toString(), url);
    }
    for (final url in [
      'https://vimeo.com.evil.test/123',
      'https://drive.google.com.evil.test/file/d/abc/view',
      'https://evilsharepoint.com/:v:/abc',
      'https://notbox.com/s/abc',
      'https://example.com/video.mp4',
    ]) {
      expect(OnlineVideo.parse(url), isNull);
    }
  });
  test('thumbnail metadata reads Vimeo JSON and public storage HTML', () {
    final vimeo = OnlineVideo.parse('https://vimeo.com/123')!;
    expect(
      OnlineVideoThumbnail.metadataImage(
        vimeo,
        '{"thumbnail_url":"https://i.vimeocdn.com/video/123.jpg"}',
      ).toString(),
      'https://i.vimeocdn.com/video/123.jpg',
    );
    final storage = OnlineVideo.parse('https://1drv.ms/v/abc')!;
    expect(
      OnlineVideoThumbnail.metadataImage(
        storage,
        '<meta content="https://example.com/thumb.jpg?a=1&amp;b=2" property="og:image">',
      ).toString(),
      'https://example.com/thumb.jpg?a=1&b=2',
    );
    expect(
      OnlineVideoThumbnail.metadataImage(
        storage,
        '<meta property="og:image" content="javascript:bad">',
      ),
      isNull,
    );
    expect(
      OnlineVideoThumbnail.metadataImage(storage, '<html>Sign in</html>'),
      isNull,
    );
  });
  for (final entry in {
    'Vimeo': 'https://vimeo.com/123456789',
    'Google Drive': 'https://drive.google.com/file/d/abc/view',
    'Dropbox': 'https://www.dropbox.com/s/abc/lesson.mp4?dl=0',
    'OneDrive': 'https://1drv.ms/v/abc',
  }.entries) {
    testWidgets(
      '${entry.key} card shows browser fallback and correct playback option',
      (tester) async {
        final state = VideoComponentState(mediaPath: entry.value);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VideoComponentView(
                state: state,
                isSelected: true,
                onSelect: () {},
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text(entry.key), findsOneWidget);
        expect(find.text('Open in browser'), findsOneWidget);
        expect(find.text(entry.value), findsOneWidget);
        expect(
          find.byTooltip('Play ${entry.key} video'),
          entry.key == 'OneDrive' ? findsNothing : findsOneWidget,
        );
        if (entry.key == 'OneDrive') {
          expect(find.text('Open video'), findsNothing);
          String? openedUrl;
          const channel = MethodChannel('plugins.flutter.io/url_launcher');
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            (call) async {
              openedUrl = (call.arguments as Map)['url'] as String;
              return true;
            },
          );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockMethodCallHandler(channel, null),
          );
          await tester.tap(find.text('Open in browser'));
          await tester.pump();
          expect(openedUrl, entry.value);
        }
        await tester.pumpWidget(const SizedBox());
        state.dispose();
      },
    );
  }
}
