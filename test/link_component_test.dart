import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/components/link_component.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LinkComponentState', () {
    test('accepts web URLs and adds https to bare domains', () {
      expect(
        LinkComponentState.parseWebUri('https://example.com/path').toString(),
        'https://example.com/path',
      );
      expect(
        LinkComponentState.parseWebUri('example.com/path').toString(),
        'https://example.com/path',
      );
      expect(LinkComponentState.parseWebUri('javascript:alert(1)'), isNull);
      expect(LinkComponentState.parseWebUri(''), isNull);
    });
  });

  testWidgets('shows URL when title is empty and title when provided', (
    tester,
  ) async {
    final state = LinkComponentState(url: 'https://example.com');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LinkComponentView(
            state: state,
            isSelected: false,
            onSelect: () {},
          ),
        ),
      ),
    );

    expect(find.text('https://example.com'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LinkComponentView(
            state: state,
            isSelected: true,
            onSelect: () {},
          ),
        ),
      ),
    );
    expect(find.byType(TextField), findsNWidgets(2));

    state.updateTitle('Example site');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LinkComponentView(
            state: state,
            isSelected: false,
            onSelect: () {},
          ),
        ),
      ),
    );
    expect(find.text('Example site'), findsOneWidget);
    expect(find.text('https://example.com'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('clicking blank space beside a link selects the component', (
    tester,
  ) async {
    final state = LinkComponentState(
      url: 'https://example.com',
      title: 'Example',
    );
    var selected = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LinkComponentView(
            state: state,
            isSelected: false,
            onSelect: () => selected = true,
          ),
        ),
      ),
    );

    final linkSize = tester.getSize(find.byType(LinkComponentView));
    await tester.tapAt(Offset(linkSize.width - 8, linkSize.height / 2));
    expect(selected, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
}
