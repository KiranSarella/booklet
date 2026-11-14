import 'dart:convert';

import 'package:booklet/ui/reader/reader_start_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('booklet/open_file'),
          (_) async => null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('booklet/open_file'),
          null,
        );
  });
  for (final size in [const Size(400, 800), const Size(800, 1100)]) {
    testWidgets('reader recents open and remove with touch at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const uri = 'content://provider/document/study';
      SharedPreferences.setMockInitialValues({
        'booklets.recents.v1': [uri],
        'booklets.recentNames.v1': jsonEncode({uri: 'Study.booklet'}),
      });
      String? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderStartView(
              busy: false,
              onOpen: () {},
              onOpenRecent: (path) => opened = path,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Recents'), findsOneWidget);
      await tester.tap(find.text('Study.booklet'));
      expect(opened, uri);
      opened = null;
      await tester.tap(find.byTooltip('Remove from recents'));
      await tester.pumpAndSettle();
      expect(find.text('Study.booklet'), findsNothing);
      expect(find.text('No recent booklets yet.'), findsOneWidget);
      expect(opened, isNull);
      expect(tester.takeException(), isNull);
    });
  }
}
