import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/video_component.dart';
import 'package:flutter/material.dart';
import 'package:booklet/ui/components/media/youtube_video.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const id = 'dQw4w9WgXcQ';
  testWidgets('video component routes YouTube URLs to inline player preview', (
    tester,
  ) async {
    final state = VideoComponentState(mediaPath: 'https://youtu.be/$id');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoComponentView(
            state: state,
            isSelected: false,
            onSelect: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byTooltip('Play YouTube video'), findsOneWidget);
    expect(find.text('Video unavailable'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
  test('recognizes supported YouTube URL formats', () {
    for (final url in [
      'https://www.youtube.com/watch?v=$id&feature=shared',
      'https://youtu.be/$id?si=abc',
      'https://m.youtube.com/watch?v=$id',
      'https://www.youtube.com/shorts/$id',
      'https://www.youtube.com/live/$id',
      'https://www.youtube-nocookie.com/embed/$id',
    ]) {
      expect(YoutubeVideo.parse(url)?.id, id, reason: url);
    }
  });
  test('rejects unrelated hosts, malformed IDs, and non-video pages', () {
    for (final url in [
      'https://youtube.com.evil.com/watch?v=$id',
      'https://example.com/video.mp4',
      'https://youtube.com/watch?v=bad',
      'https://youtube.com/playlist?list=abc',
      'file:///watch?v=$id',
    ]) {
      expect(YoutubeVideo.parse(url), isNull, reason: url);
    }
  });
  test('preserves playback timestamps in safe embed URL', () {
    final video = YoutubeVideo.parse('https://youtu.be/$id?t=1h2m3s')!;
    expect(video.startSeconds, 3723);
    expect(video.embedUri.host, 'www.youtube-nocookie.com');
    expect(video.embedUri.path, '/embed/$id');
    expect(video.embedUri.queryParameters['start'], '3723');
    expect(video.embedUri.queryParameters['origin'], YoutubeVideo.appOrigin);
    expect(
      YoutubeVideo.parse('https://youtu.be/$id?start=90')!.startSeconds,
      90,
    );
  });
}
