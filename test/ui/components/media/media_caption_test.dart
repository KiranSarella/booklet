import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/components/media/media_caption.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final kind in ['image', 'video']) {
    testWidgets(
      '$kind caption follows selection and preserves multiline input',
      (tester) async {
        final CaptionedMediaComponentState state = kind == 'image'
            ? ImageComponentState()
            : VideoComponentState();
        var notifications = 0;
        state.addListener(() => notifications++);
        Future<void> show(bool selected, {bool readOnly = false}) =>
            tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: MediaCaption(
                    state: state,
                    isSelected: selected,
                    isReadOnly: readOnly,
                    onSelect: () {},
                    child: const SizedBox(height: 100),
                  ),
                ),
              ),
            );
        await show(false);
        expect(find.byType(TextField), findsNothing);
        expect(find.text('Add caption'), findsNothing);
        await show(true);
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.textAlign, TextAlign.center);
        expect(field.maxLines, isNull);
        expect(field.style!.color, Colors.grey);
        await tester.enterText(
          find.byType(TextField),
          'First line\nSecond line',
        );
        expect(state.caption, 'First line\nSecond line');
        expect(notifications, greaterThan(0));
        await show(false);
        expect(find.byType(TextField), findsNothing);
        expect(find.text('First line\nSecond line'), findsOneWidget);
        await show(true, readOnly: true);
        expect(
          tester.widget<TextField>(find.byType(TextField)).readOnly,
          isTrue,
        );
        state.caption = '';
        await show(false);
        expect(find.text('Add caption'), findsNothing);
        await show(true);
        expect(find.text('Add caption'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        state.dispose();
      },
    );
  }
  for (final width in [800.0, 280.0]) {
    testWidgets('source row sits between preview and caption at width $width', (
      tester,
    ) async {
      final state = ImageComponentState()..caption = 'Caption below source';
      const url = 'https://images.example.com/photo.jpg';
      const previewKey = ValueKey('preview');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: width,
              child: MediaCaption(
                state: state,
                isSelected: true,
                onSelect: () {},
                sourceUrl: url,
                child: const SizedBox(
                  key: previewKey,
                  height: 100,
                  width: double.infinity,
                ),
              ),
            ),
          ),
        ),
      );
      final source = find.text(url);
      final button = find.text('Open in browser');
      final caption = find.text(state.caption);
      expect(source, findsOneWidget);
      expect(button, findsOneWidget);
      expect(
        tester.getTopLeft(source).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.byKey(previewKey)).dy),
      );
      expect(
        tester.getTopLeft(caption).dy,
        greaterThan(tester.getBottomLeft(source).dy),
      );
      expect(
        tester.getTopLeft(caption).dy,
        greaterThan(tester.getBottomLeft(button).dy),
      );
      state.caption = '';
      await tester.pump();
      expect(source, findsOneWidget);
      expect(button, findsOneWidget);
      expect(find.text('Add caption'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaCaption(
              state: state,
              isSelected: true,
              onSelect: () {},
              sourceUrl: '/tmp/local.png',
              child: const SizedBox(),
            ),
          ),
        ),
      );
      expect(find.text('Open in browser'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    });
  }
  for (final readOnly in [false, true]) {
    for (final kind in ['image', 'video']) {
      testWidgets(
        '$kind source actions follow selection in readOnly=$readOnly',
        (tester) async {
          final CaptionedMediaComponentState state = kind == 'image'
              ? ImageComponentState()
              : VideoComponentState();
          state.caption = 'Visible caption';
          const url = 'https://example.com/media';
          Future<void> show(bool selected) => tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: MediaCaption(
                  state: state,
                  isSelected: selected,
                  isReadOnly: readOnly,
                  sourceUrl: url,
                  onSelect: () {},
                  child: const SizedBox(height: 100),
                ),
              ),
            ),
          );
          await show(false);
          expect(find.text(url), findsNothing);
          expect(find.text('Open in browser'), findsNothing);
          expect(find.text('Visible caption'), findsOneWidget);
          await show(true);
          expect(find.text(url), findsOneWidget);
          expect(find.text('Open in browser'), findsOneWidget);
          await show(false);
          expect(find.text(url), findsNothing);
          expect(find.text('Open in browser'), findsNothing);
          expect(find.text('Visible caption'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
          state.dispose();
        },
      );
    }
  }
}
