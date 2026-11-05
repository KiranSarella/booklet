import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/link_component.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    expect(find.byTooltip('Open in browser'), findsOneWidget);
    expect(find.byTooltip('Edit link'), findsNothing);
    expect(
      tester.widget<Text>(find.text('https://example.com')).style?.decoration,
      isNot(TextDecoration.underline),
    );

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
    expect(find.byType(TextField), findsNothing);
    expect(find.byTooltip('Open in browser'), findsOneWidget);
    expect(find.byTooltip('Edit link'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit link'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
    expect(state.urlFocusNode.hasFocus, isTrue);
    expect(state.isFocused, isTrue);

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData'
          ? {'text': 'https://pasted.example'}
          : null,
    );
    state.urlController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: state.urlController.text.length,
    );
    await tester.pump();
    final editable = tester.state<EditableTextState>(
      find.byType(EditableText).first,
    );
    await editable.pasteText(SelectionChangedCause.keyboard);
    await tester.pump();
    expect(state.url, 'https://pasted.example');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(state.isFocused, isFalse);

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
