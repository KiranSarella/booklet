import 'dart:io';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// Stores original local paths or Android document URIs, never extracted paths.
class RecentBooklets {
  static const _channel = MethodChannel('booklet/document_file');

  static bool _isDocumentUri(String path) =>
      const ['content', 'file'].contains(Uri.tryParse(path)?.scheme);

  static Future<String> restoreAccess(String path) async {
    if (_isDocumentUri(path)) {
      final opened = await const MethodChannel('booklet/open_file')
          .invokeMethod<String>('reopenBooklet', {'uri': path});
      if (opened == null) throw StateError('Could not reopen booklet.');
      return opened;
    }
    if (!Platform.isMacOS) return path;
    try {
      return await _channel.invokeMethod<String>('restoreAccess', {
            'destination': path,
          }) ??
          path;
    } on MissingPluginException {
      return path;
    }
  }

  static const _key = 'booklets.recents.v1';
  static const _namesKey = 'booklets.recentNames.v1';
  static const limit = 10;

  static Future<List<String>> load() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    final paths = preferences.getStringList(_key) ?? <String>[];
    return List.unmodifiable(
      paths.where(
        (path) => !Platform.isAndroid || !path.contains('/cache/reader/'),
      ),
    );
  }

  static Future<List<RecentBooklet>> loadEntries() async {
    final paths = await load();
    final preferences = await SharedPreferences.getInstance();
    final names = jsonDecode(preferences.getString(_namesKey) ?? '{}') as Map;
    return [
      for (final path in paths)
        RecentBooklet(
          path: path,
          name: names[path] as String? ?? p.basename(path),
        ),
    ];
  }

  static Future<void> remove(String path) async {
    final paths = await load();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _key,
      paths.where((entry) => entry != path).toList(),
    );
    final names = jsonDecode(preferences.getString(_namesKey) ?? '{}') as Map;
    names.remove(path);
    await preferences.setString(_namesKey, jsonEncode(names));
    await _forgetAccess(path);
  }

  static Future<void> _forgetAccess(String path) async {
    if (!_isDocumentUri(path)) return;
    try {
      await const MethodChannel('booklet/open_file')
          .invokeMethod<void>('forgetBooklet', {'uri': path});
    } on PlatformException {
      // History removal still works if a provider already revoked permission.
    } on MissingPluginException {
      // Headless tests have no Android permission bridge.
    }
  }

  static Future<void> recordAndroidDocument(String extractedPath) async {
    final source = File('$extractedPath/.booklet-source.json');
    if (!await source.exists()) return;
    final metadata = jsonDecode(await source.readAsString()) as Map;
    await record(
      metadata['uri'] as String,
      displayName: metadata['name'] as String?,
    );
  }

  static Future<void> record(String path, {String? displayName}) async {
    if (Platform.isAndroid && !_isDocumentUri(path)) {
      return recordAndroidDocument(path);
    }
    final name = displayName;
    final normalized = _isDocumentUri(path)
        ? path
        : p.normalize(p.absolute(path));
    if (Platform.isMacOS && !_isDocumentUri(normalized)) {
      try {
        await _channel.invokeMethod<void>('rememberAccess', {
          'destination': normalized,
        });
      } on MissingPluginException {
        // Headless tests do not have a native file-access channel.
      }
    }
    final paths = await load();
    final preferences = await SharedPreferences.getInstance();
    final retainedPaths = [
      normalized,
      ...paths.where((entry) => entry != normalized),
    ].take(limit).toList();
    if (name != null) {
      final names = jsonDecode(preferences.getString(_namesKey) ?? '{}') as Map;
      names[normalized] = name;
      final retained = retainedPaths.toSet();
      names.removeWhere((key, _) => !retained.contains(key));
      await preferences.setString(_namesKey, jsonEncode(names));
    }
    await preferences.setStringList(_key, retainedPaths);
    for (final evicted in paths.where(
      (entry) => !retainedPaths.contains(entry),
    )) {
      await _forgetAccess(evicted);
    }
  }
}

class RecentBooklet {
  const RecentBooklet({required this.path, required this.name});
  final String path;
  final String name;
}
