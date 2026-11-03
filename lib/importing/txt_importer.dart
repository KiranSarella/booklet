import 'dart:convert';
import 'dart:io';

import 'html_importer.dart';

class TxtImporter {
  static const maxBytes = 10 * 1024 * 1024;

  static Future<HtmlImportResult> load(String path) async {
    final file = File(path);
    if (await file.length() > maxBytes) {
      throw const FormatException('TXT file is too large (maximum 10 MB).');
    }
    final bytes = await file.readAsBytes();
    String text;
    if (bytes.length >= 2 &&
        ((bytes[0] == 0xff && bytes[1] == 0xfe) ||
            (bytes[0] == 0xfe && bytes[1] == 0xff))) {
      if (bytes.length.isOdd) {
        throw const FormatException('Invalid UTF-16 text file.');
      }
      final little = bytes[0] == 0xff;
      text = String.fromCharCodes([
        for (var i = 2; i < bytes.length; i += 2)
          little ? bytes[i] | bytes[i + 1] << 8 : bytes[i] << 8 | bytes[i + 1],
      ]);
    } else {
      try {
        text = utf8.decode(bytes);
      } on FormatException {
        throw const FormatException(
          'Save this text file as UTF-8 or UTF-16 before importing.',
        );
      }
    }
    text = text
        .replaceFirst(RegExp('^\uFEFF'), '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    if (text.contains('\u0000')) {
      throw const FormatException(
        'This file contains binary data or unsupported text encoding.',
      );
    }
    if (text.trim().isEmpty) {
      throw const FormatException('This text file is empty.');
    }
    final blocks = text.split(RegExp(r'\n[ \t]*\n')).map((paragraph) {
      return HtmlImportBlock(
        'text',
        delta: [
          {'insert': paragraph.endsWith('\n') ? paragraph : '$paragraph\n'},
        ],
      );
    }).toList();
    return HtmlImportResult(
      file.uri.pathSegments.last.replaceFirst(
        RegExp(r'\.txt$', caseSensitive: false),
        '',
      ),
      blocks,
    );
  }
}
