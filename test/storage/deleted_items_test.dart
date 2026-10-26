import 'dart:io';

import 'package:booklet/storage/deleted_items.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory package;
  setUp(() async {
    package = await Directory.systemTemp.createTemp('deleted_items_test');
  });
  tearDown(() async {
    await package.delete(recursive: true);
  });
  Map<String, dynamic> bundle(String title) => {
    'node': {'title': title, 'type': 'page', 'pageId': 'page'},
    'pages': {},
    'resources': {'media/a': 'AQID'},
  };

  test('retains complete bundle and deletes exactly at 30 days', () async {
    final deleted = DateTime.utc(2026, 1, 1, 12);
    final item = await DeletedItems.add(
      package.path,
      bundle('Page'),
      now: deleted,
    );
    expect(
      (await DeletedItems.list(
        package.path,
        now: deleted
            .add(const Duration(days: 30))
            .subtract(const Duration(seconds: 1)),
      )).single.title,
      'Page',
    );
    expect(
      await File('${DeletedItems.root(package.path)}/${item.id}.json').exists(),
      true,
    );
    expect(
      await DeletedItems.list(
        package.path,
        now: deleted.add(const Duration(days: 30)),
      ),
      isEmpty,
    );
    expect(
      await File('${DeletedItems.root(package.path)}/${item.id}.json').exists(),
      false,
    );
  });

  test(
    'permanent deletion removes archive; copied entries preserve expiry',
    () async {
      final target = await Directory.systemTemp.createTemp(
        'deleted_items_target',
      );
      try {
        final item = await DeletedItems.add(package.path, bundle('Page'));
        await DeletedItems.copyEntries(package.path, target.path);
        expect((await DeletedItems.read(target.path, item.id))['resources'], {
          'media/a': 'AQID',
        });
        expect(
          (await DeletedItems.list(target.path)).single.deletedAt,
          item.deletedAt,
        );
        await DeletedItems.delete(target.path, item.id);
        expect(await DeletedItems.list(target.path), isEmpty);
      } finally {
        await target.delete(recursive: true);
      }
    },
  );
}
