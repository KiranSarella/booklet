import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

class DeletedItem {
  const DeletedItem({
    required this.id,
    required this.title,
    required this.type,
    required this.deletedAt,
  });
  final String id;
  final String title;
  final String type;
  final DateTime deletedAt;
  DateTime get expiresAt => deletedAt.add(const Duration(days: 30));
}

/// Each entry is a self-contained subtree export, including its media.
class DeletedItems {
  static String root(String package) => '$package/.deleted_items';
  static File _file(String package, String id) {
    if (!RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(id)) {
      throw ArgumentError('Invalid deleted item ID');
    }
    return File('${root(package)}/$id.json');
  }

  static Future<DeletedItem> add(
    String package,
    Map<String, dynamic> bundle, {
    DateTime? now,
  }) async {
    final id = const Uuid().v4();
    final deletedAt = (now ?? DateTime.now()).toUtc();
    final node = bundle['node'] as Map;
    final file = _file(package, id);
    await file.parent.create(recursive: true);
    final staged = File('${file.path}.tmp');
    await staged.writeAsString(
      jsonEncode({'deletedAt': deletedAt.toIso8601String(), 'bundle': bundle}),
      flush: true,
    );
    await staged.rename(file.path);
    return DeletedItem(
      id: id,
      title: node['title'] as String,
      type: node['type'] as String,
      deletedAt: deletedAt,
    );
  }

  static Future<List<DeletedItem>> list(String package, {DateTime? now}) async {
    final directory = Directory(root(package));
    if (!await directory.exists()) return [];
    final result = <DeletedItem>[];
    final current = (now ?? DateTime.now()).toUtc();
    await for (final file in directory.list(followLinks: false)) {
      if (file is! File || !file.path.endsWith('.json')) continue;
      final data = jsonDecode(await file.readAsString()) as Map;
      final node = (data['bundle'] as Map)['node'] as Map;
      final item = DeletedItem(
        id: file.uri.pathSegments.last.replaceFirst('.json', ''),
        title: node['title'] as String,
        type: node['type'] as String,
        deletedAt: DateTime.parse(data['deletedAt'] as String).toUtc(),
      );
      if (!current.isBefore(item.expiresAt)) {
        await file.delete();
      } else {
        result.add(item);
      }
    }
    result.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
    return result;
  }

  static Future<Map<String, dynamic>> read(String package, String id) async {
    final data = jsonDecode(await _file(package, id).readAsString()) as Map;
    final deletedAt = DateTime.parse(data['deletedAt'] as String);
    if (!DateTime.now().toUtc().isBefore(
      deletedAt.add(const Duration(days: 30)),
    )) {
      await delete(package, id);
      throw StateError('This deleted item has expired.');
    }
    return Map<String, dynamic>.from(data['bundle'] as Map);
  }

  static Future<void> delete(String package, String id) async {
    final file = _file(package, id);
    if (await file.exists()) await file.delete();
  }

  static Future<void> copyEntries(String source, String target) async {
    if (Directory(source).absolute.path == Directory(target).absolute.path) {
      return;
    }
    final entries = await list(source);
    if (entries.isEmpty) return;
    await Directory(root(target)).create(recursive: true);
    for (final entry in entries) {
      await _file(source, entry.id).copy(_file(target, entry.id).path);
    }
  }
}
