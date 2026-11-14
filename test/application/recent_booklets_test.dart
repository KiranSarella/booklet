import 'dart:io';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:booklet/application/recent_booklets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('history persists paths with the most recently opened first', () async {
    expect(await RecentBooklets.load(), isEmpty);
    await RecentBooklets.record('/books/first.booklet');
    await RecentBooklets.record('/books/second.booklet');
    await RecentBooklets.record('/books/./first.booklet');
    expect(await RecentBooklets.load(), [
      p.normalize('/books/first.booklet'),
      p.normalize('/books/second.booklet'),
    ]);
  });

  test('macOS stores and restores access through the native channel', () async {
    if (!Platform.isMacOS) return;
    const channel = MethodChannel('booklet/document_file');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'restoreAccess' ? '/moved/book.booklet' : null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    await RecentBooklets.record('/books/book.booklet');
    expect(calls.single.method, 'rememberAccess');
    expect(calls.single.arguments, {'destination': '/books/book.booklet'});
    expect(
      await RecentBooklets.restoreAccess('/books/book.booklet'),
      '/moved/book.booklet',
    );
    expect(calls.last.method, 'restoreAccess');
  });

  test('history retains only the ten most recent booklets', () async {
    for (var i = 0; i < 12; i++) {
      await RecentBooklets.record('/books/$i.booklet');
    }
    final paths = await RecentBooklets.load();
    expect(paths, hasLength(10));
    expect(paths.first, p.normalize('/books/11.booklet'));
    expect(paths.last, p.normalize('/books/2.booklet'));
  });
  test('Android history persists the original URI and display name across cache deletion', () async {
    final cache = await Directory.systemTemp.createTemp('reader_recents_test_');
    const uri = 'content://provider/document/primary%3ABooks%2FStudy.booklet';
    await File('${cache.path}/.booklet-source.json')
        .writeAsString(jsonEncode({'uri': uri, 'name': 'Study.booklet'}));
    await RecentBooklets.recordAndroidDocument(cache.path);
    await cache.delete(recursive: true);
    expect(await RecentBooklets.load(), [uri]);
    expect((await RecentBooklets.loadEntries()).single.name, 'Study.booklet');
    const channel = MethodChannel('booklet/open_file');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'reopenBooklet' ? '/fresh/cache' : null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    expect(await RecentBooklets.restoreAccess(uri), '/fresh/cache');
    expect(calls.single.method, 'reopenBooklet');
    expect(calls.single.arguments, {'uri': uri});
    await RecentBooklets.remove(uri);
    expect(await RecentBooklets.load(), isEmpty);
    expect(calls.last.method, 'forgetBooklet');
  });
}
