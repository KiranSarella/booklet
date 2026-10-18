import 'package:booklet/ui/components/inbuilt_components/component_defs/embed_component.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_all/webview_all.dart';

void main() {
  group('EmbedContentParser', () {
    test('converts a YouTube iframe snippet to a privacy-enhanced embed', () {
      const snippet = '''
<iframe width="560" height="315" src="https://www.youtube.com/embed/dQw4w9WgXcQ?si=abc" title="YouTube video" allowfullscreen></iframe>
''';
      final target = EmbedContentParser.parse(snippet);

      expect(target, isNotNull);
      expect(target!.provider, EmbedProvider.youtube);
      expect(
        target.html,
        contains('https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ?'),
      );
      expect(
        target.thumbnailUrl,
        'https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
      );
      expect(
        target.requestUri?.toString(),
        contains('origin=https%3A%2F%2Fwww.youtube-nocookie.com'),
      );
    });

    test(
      'converts an X/Twitter blockquote snippet to an official tweet embed',
      () {
        const snippet = '''
<blockquote class="twitter-tweet"><p>Post contents</p><a href="https://twitter.com/example/status/1234567890123456789?ref_src=twsrc%5Etfw">April 2026</a></blockquote><script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>
''';
        final target = EmbedContentParser.parse(snippet);

        expect(target, isNotNull);
        expect(target!.provider, EmbedProvider.x);
        expect(target.html, contains('widgets.js'));
        expect(target.html, contains('/i/status/1234567890123456789'));
      },
    );

    test('rejects plain links and malformed or spoofed embeds', () {
      expect(
        EmbedContentParser.parse('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        isNull,
      );
      expect(
        EmbedContentParser.parse(
          '<iframe src="https://youtube.com.evil.example/embed/dQw4w9WgXcQ"></iframe>',
        ),
        isNull,
      );
      expect(
        EmbedContentParser.parse(
          'https://x.com/example/status/1234567890123456789',
        ),
        isNull,
      );
      expect(
        EmbedContentParser.parse(
          '<blockquote><a href="https://x.com/example/status/not-a-number">Post</a></blockquote>',
        ),
        isNull,
      );
    });
  });

  testWidgets('X embed shows a preview card before loading the WebView', (
    tester,
  ) async {
    const snippet = '''
<blockquote class="twitter-tweet"><a href="https://x.com/example/status/1234567890123456789">Post</a></blockquote><script src="https://platform.twitter.com/widgets.js"></script>
''';
    final state = EmbedComponentState(content: snippet);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmbedComponentView(
            state: state,
            isSelected: false,
            onSelect: () {},
          ),
        ),
      ),
    );

    expect(find.text('View post from X / Twitter'), findsOneWidget);
    expect(find.text('Load embed'), findsOneWidget);
    expect(find.byType(WebViewWidget), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
}
