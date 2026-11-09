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

  test('accepts maps, forms, and Instagram embeds', () {
    for (final source in [
      'https://www.google.com/maps/embed?pb=test',
      'https://docs.google.com/forms/d/e/form/viewform?embedded=true',
    ]) {
      final target = EmbedContentParser.parse(
        '<iframe title="Widget" src="$source"></iframe>',
      )!;
      expect(target.provider, EmbedProvider.iframe);
      expect(target.requestUri.toString(), source);
      expect(target.title, 'Widget');
    }
    final instagram = EmbedContentParser.parse(
      '<blockquote class="instagram-media" data-instgrm-permalink="https://www.instagram.com/reels/DcJfWVNtLzJ/"></blockquote>',
    )!;
    expect(instagram.provider, EmbedProvider.instagram);
    expect(instagram.requestUri!.path, '/p/DcJfWVNtLzJ/embed/captioned/');
    expect(
      EmbedContentParser.parse('<iframe src="javascript:alert(1)"></iframe>'),
      isNull,
    );
    expect(
      EmbedContentParser.parse(
        '<script src="https://example.com/script.js"></script>',
      ),
      isNull,
    );
  });

  testWidgets('selected embeds keep previews visible and edit explicitly', (
    tester,
  ) async {
    final state = EmbedComponentState(
      content: '<iframe title="Office map" src="https://maps.example.com/embed"></iframe>',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmbedComponentView(
            state: state,
            isSelected: true,
            onSelect: () {},
          ),
        ),
      ),
    );
    expect(find.text('Office map'), findsOneWidget);
    expect(find.text('Load embed'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byTooltip('Open in browser'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit embed code'));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'invalid');
    await tester.tap(find.text('Show embed'));
    await tester.pump();
    expect(
      find.text('Paste an iframe or an Instagram/X post embed.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });

  testWidgets('read-only embeds hide editing controls', (tester) async {
    final state = EmbedComponentState(
      content:
          '<iframe title="Map" src="https://maps.example.com/embed"></iframe>',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmbedComponentView(
            state: state,
            isSelected: true,
            isReadOnly: true,
            onSelect: () {},
          ),
        ),
      ),
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.byTooltip('Edit embed code'), findsNothing);
    expect(find.text('Load embed'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
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
