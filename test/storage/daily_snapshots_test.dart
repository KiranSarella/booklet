import 'dart:io';

import 'package:booklet/storage/daily_snapshots.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory package;
  setUp(() async {
    package = await Directory.systemTemp.createTemp('booklet_daily_test');
    await File('${package.path}/content.json').writeAsString('original');
    await Directory('${package.path}/media').create();
    await File('${package.path}/media/photo.png').writeAsBytes([1, 2, 3]);
    await Directory(DailySnapshots.root(package.path)).create();
    await File('${DailySnapshots.root(package.path)}/last_day')
        .writeAsString('2026-10-24');
  });
  tearDown(() async {
    await package.delete(recursive: true);
  });

  test(
    'manual backups include media and preserve multiple copies per day',
    () async {
      final first = await DailySnapshots.create(
        package.path,
        now: DateTime(2026, 10, 26),
      );
      await File('${package.path}/content.json').writeAsString('edited');
      final second = await DailySnapshots.create(
        package.path,
        now: DateTime(2026, 10, 26),
      );
      expect(second, isNot(first));
      final saved = '${DailySnapshots.root(package.path)}/$first';
      expect(await File('$saved/content.json').readAsString(), 'original');
      expect(await File('$saved/media/photo.png').readAsBytes(), [1, 2, 3]);
      expect(await Directory('$saved/.daily_snapshots').exists(), false);
      expect((await DailySnapshots.list(package.path)).length, 2);
      await DailySnapshots.delete(package.path, first);
      expect((await DailySnapshots.list(package.path)).single.day, second);
    },
  );

  test('manual backups are retained until explicitly deleted', () async {
    for (var d = 1; d <= 8; d++) {
      await DailySnapshots.create(package.path, now: DateTime(2026, 10, d));
    }
    expect((await DailySnapshots.list(package.path)).length, 8);
  });

  test(
    'examining and discarding leave original untouched, including media',
    () async {
      await DailySnapshots.copyPackage(
        package.path,
        '${DailySnapshots.root(package.path)}/2026-10-24',
      );
      await File('${package.path}/content.json').writeAsString('current');
      await DailySnapshots.examine(package.path, '2026-10-24');
      expect(await DailySnapshots.activeDay(package.path), '2026-10-24');
      await File('${DailySnapshots.working(package.path)}/content.json')
          .writeAsString('examined edits');
      expect(
        await File('${package.path}/content.json').readAsString(),
        'current',
      );
      await DailySnapshots.discard(package.path);
      expect(await DailySnapshots.activeDay(package.path), null);
      expect(
        await File('${package.path}/content.json').readAsString(),
        'current',
      );
      expect(
        await Directory(DailySnapshots.working(package.path)).exists(),
        false,
      );
    },
  );

  test('keep adopts examined changes and replaces removed files', () async {
    await DailySnapshots.copyPackage(
      package.path,
      '${DailySnapshots.root(package.path)}/2026-10-24',
    );
    await File('${package.path}/extra.txt').writeAsString('new file');
    await DailySnapshots.examine(package.path, '2026-10-24');
    await File('${DailySnapshots.working(package.path)}/content.json')
        .writeAsString('kept edits');
    await DailySnapshots.keep(package.path);
    expect(
      await File('${package.path}/content.json').readAsString(),
      'kept edits',
    );
    expect(await File('${package.path}/extra.txt').exists(), false);
    expect(await File('${package.path}/media/photo.png').readAsBytes(), [
      1,
      2,
      3,
    ]);
    expect(await DailySnapshots.activeDay(package.path), null);
    expect((await DailySnapshots.list(package.path)).length, 1);
  });

  test('interrupted keep rolls back from recovery copy', () async {
    final backup = '${DailySnapshots.root(package.path)}/before_keep';
    await DailySnapshots.copyPackage(package.path, backup);
    await File('${package.path}/content.json').delete();
    await DailySnapshots.recover(package.path);
    expect(
      await File('${package.path}/content.json').readAsString(),
      'original',
    );
    expect(await Directory(backup).exists(), false);
  });
}
