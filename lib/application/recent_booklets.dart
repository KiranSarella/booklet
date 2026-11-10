import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// Stores original local paths, never temporary extracted archive paths.
class RecentBooklets {
  static const _channel = MethodChannel('booklet/document_file');

  static Future<String> restoreAccess(String path) async {
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
  static const limit = 10;

  static Future<List<String>> load() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    return List.unmodifiable(preferences.getStringList(_key) ?? <String>[]);
  }

  static Future<void> remove(String path) async {
    final paths = await load();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _key,
      paths.where((entry) => entry != path).toList(),
    );
  }

  static Future<void> record(String path) async {
    final normalized = p.normalize(p.absolute(path));
    if (Platform.isMacOS) {
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
    await preferences.setStringList(
      _key,
      [
        normalized,
        ...paths.where((entry) => entry != normalized),
      ].take(limit).toList(),
    );
  }
}
