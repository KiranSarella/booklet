import 'dart:io';

import 'package:flutter/services.dart';

/// Keeps installed fonts distinct from Google fonts in saved preferences/themes.
abstract final class SystemFonts {
  static const prefix = 'system-font:';
  static const _channel = MethodChannel('booklet/system_fonts');

  static String encode(String family) => '$prefix$family';
  static String label(String font) =>
      font.startsWith(prefix) ? font.substring(prefix.length) : font;

  static Future<List<String>> availableFamilies() async {
    final List<String> families;
    if (Platform.isMacOS) {
      families = await _channel.invokeListMethod<String>('listFamilies') ?? [];
    } else if (Platform.isLinux) {
      final result = await Process.run('fc-list', ['--format=%{family}\\n']);
      if (result.exitCode != 0) {
        throw StateError('Unable to read installed fonts.');
      }
      families = (result.stdout as String)
          .split('\n')
          .expand((line) => line.split(','))
          .toList();
    } else {
      throw UnsupportedError(
        'System font discovery is unavailable on this platform.',
      );
    }
    return families
        .map((font) => font.trim())
        .where((font) => font.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }
}
