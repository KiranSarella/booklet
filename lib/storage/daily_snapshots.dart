import 'dart:convert';
import 'dart:io';

class DailySnapshot {
  const DailySnapshot(this.day, this.bytes);
  final String day;
  final int bytes;
}

/// Snapshots contain complete packages, including media. The live package is
/// untouched while a restored version is being examined.
class DailySnapshots {
  static String root(String package) => '$package/.daily_snapshots';
  static String working(String package) => '${root(package)}/working';
  static String day(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  static Future<void> copyPackage(
    String source,
    String target, {
    bool includeDeletedItems = true,
  }) async {
    await Directory(target).create(recursive: true);
    await for (final entry in Directory(source).list(followLinks: false)) {
      final name = entry.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (name == '.daily_snapshots' ||
          (!includeDeletedItems && name == '.deleted_items')) {
        continue;
      }
      await _copy(entry, '$target/$name');
    }
  }

  static Future<void> _copy(FileSystemEntity entry, String target) async {
    if (entry is File) {
      await entry.copy(target);
    } else if (entry is Directory) {
      await Directory(target).create(recursive: true);
      await for (final child in entry.list(followLinks: false)) {
        final name = child.uri.pathSegments.where((s) => s.isNotEmpty).last;
        await _copy(child, '$target/$name');
      }
    } else {
      throw FileSystemException('Cannot snapshot symbolic links', entry.path);
    }
  }

  static Future<List<DailySnapshot>> list(String package) async {
    final directory = Directory(root(package));
    if (!await directory.exists()) return [];
    final snapshots = <DailySnapshot>[];
    await for (final entry in directory.list()) {
      final name = entry.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (entry is! Directory ||
          !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(name)) {
        continue;
      }
      if (!await File('${entry.path}/content.json').exists()) continue;
      var bytes = 0;
      await for (final file in entry.list(
        recursive: true,
        followLinks: false,
      )) {
        if (file is File) bytes += await file.length();
      }
      snapshots.add(DailySnapshot(name, bytes));
    }
    snapshots.sort((a, b) => b.day.compareTo(a.day));
    return snapshots;
  }

  /// Called before writing: preserve yesterday's final saved package.
  static Future<void> rollDay(String package, {DateTime? now}) async {
    final manifest = File('$package/content.json');
    if (!await manifest.exists()) return;
    final today = day(now ?? DateTime.now());
    final marker = File('${root(package)}/last_day');
    final previous = await marker.exists()
        ? (await marker.readAsString()).trim()
        : day((await manifest.stat()).modified);
    if (previous.compareTo(today) < 0) {
      final destination = Directory('${root(package)}/$previous');
      if (!await destination.exists()) {
        final staged = Directory('${root(package)}/capturing');
        if (await staged.exists()) await staged.delete(recursive: true);
        await copyPackage(package, staged.path, includeDeletedItems: false);
        await staged.rename(destination.path);
      }
      final entries = await list(package);
      for (final entry in entries.skip(6)) {
        await delete(package, entry.day);
      }
    }
    if (previous.compareTo(today) > 0) return;
    if (!await marker.exists() || previous != today) {
      await marker.parent.create(recursive: true);
      final staged = File('${marker.path}.tmp');
      await staged.writeAsString(today, flush: true);
      await staged.rename(marker.path);
    }
  }

  static Future<void> delete(String package, String snapshotDay) async {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(snapshotDay)) {
      throw ArgumentError('Invalid snapshot day');
    }
    final directory = Directory('${root(package)}/$snapshotDay');
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  static Future<String?> activeDay(String package) async {
    final marker = File('${root(package)}/session.json');
    if (!await marker.exists()) return null;
    return (jsonDecode(await marker.readAsString()) as Map)['day'] as String;
  }

  static Future<void> examine(String package, String snapshotDay) async {
    if (await activeDay(package) != null) {
      throw StateError('Finish the current restore first.');
    }
    if (!(await list(package)).any((s) => s.day == snapshotDay)) {
      throw StateError('Snapshot not found.');
    }
    final directory = Directory(working(package));
    if (await directory.exists()) await directory.delete(recursive: true);
    await copyPackage(
      '${root(package)}/$snapshotDay',
      directory.path,
      includeDeletedItems: false,
    );
    // Trash follows the current document, rather than an old snapshot's list.
    final trash = Directory('$package/.deleted_items');
    if (await trash.exists()) {
      await _copy(trash, '${directory.path}/.deleted_items');
    }
    final marker = File('${root(package)}/session.tmp');
    await marker.writeAsString(jsonEncode({'day': snapshotDay}), flush: true);
    await marker.rename('${root(package)}/session.json');
  }

  static Future<void> discard(String package) async {
    final marker = File('${root(package)}/session.json');
    if (await marker.exists()) await marker.delete();
    final directory = Directory(working(package));
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  /// Keep a recovery copy until all replacement files have been written.
  static Future<void> keep(String package) async {
    await rollDay(package);
    final backup = Directory('${root(package)}/before_keep');
    if (await backup.exists()) {
      throw StateError('A previous restore needs recovery.');
    }
    final staging = Directory('${root(package)}/preparing_keep');
    if (await staging.exists()) await staging.delete(recursive: true);
    await copyPackage(package, staging.path);
    await staging.rename(backup.path);
    try {
      await _replace(working(package), package);
      await File('${backup.path}/committed').writeAsString('yes', flush: true);
    } catch (_) {
      await _replace(backup.path, package);
      await backup.delete(recursive: true);
      rethrow;
    }
    await _finishKeep(package);
    await backup.delete(recursive: true);
  }

  static Future<String?> lastRestoredDay(String package) async {
    final marker = File('${root(package)}/restored_day');
    return await marker.exists() ? (await marker.readAsString()).trim() : null;
  }

  static Future<void> _finishKeep(String package) async {
    final restored = await activeDay(package);
    if (restored != null) {
      await File('${root(package)}/restored_day')
          .writeAsString(restored, flush: true);
    }
    await discard(package);
  }

  static Future<void> recover(String package) async {
    final backup = Directory('${root(package)}/before_keep');
    if (!await backup.exists()) return;
    if (await File('${backup.path}/committed').exists()) {
      await _finishKeep(package);
    } else {
      await _replace(backup.path, package);
    }
    await backup.delete(recursive: true);
  }

  static Future<void> _replace(String source, String target) async {
    await for (final entry in Directory(target).list(followLinks: false)) {
      final name = entry.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (name != '.daily_snapshots') await entry.delete(recursive: true);
    }
    await copyPackage(source, target);
  }
}
