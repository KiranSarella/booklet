import 'package:booklet/ui/start_booklet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows recent paths and opens the selected booklet', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'booklets.recents.v1': ['/books/travel.booklet'],
    });
    String? openedPath;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              StartBooklet(
                onCreateNew: () {},
                onOpenExisting: () async {},
                onOpenRecent: (path) async => openedPath = path,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Recents'), findsOneWidget);
    expect(find.text('/books/travel.booklet'), findsOneWidget);
    await tester.tap(find.text('travel.booklet'));
    await tester.pumpAndSettle();
    expect(openedPath, '/books/travel.booklet');
  });
  testWidgets('cross removes only its recent entry without opening it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'booklets.recents.v1': ['/books/first.booklet', '/books/second.booklet'],
    });
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              StartBooklet(
                onCreateNew: () {},
                onOpenExisting: () async {},
                onOpenRecent: (_) async {
                  opened = true;
                },
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove from recents').hitTestable(), findsNothing);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('first.booklet')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove from recents').hitTestable(), findsOneWidget);
    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove from recents').hitTestable(), findsNothing);
    await mouse.moveTo(tester.getCenter(find.text('first.booklet')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove from recents').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('first.booklet'), findsNothing);
    expect(find.text('second.booklet'), findsOneWidget);
    expect(opened, isFalse);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getStringList('booklets.recents.v1'), [
      '/books/second.booklet',
    ]);
    await mouse.moveTo(tester.getCenter(find.text('second.booklet')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove from recents').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('No recent booklets yet.'), findsOneWidget);
  });
}
