import 'package:booklet/ui/components/media/media_url_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('URL entry rejects local paths and accepts signed media URLs', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                result = await showMediaUrlDialog(context, 'video');
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '/tmp/video.mp4');
    await tester.tap(find.text('Add'));
    await tester.pump();
    expect(find.text('Enter a valid HTTP or HTTPS URL.'), findsOneWidget);
    const url = 'https://example.com/media?id=1&signature=abc';
    await tester.enterText(find.byType(TextFormField), '  $url  ');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(result, url);
  });
}
