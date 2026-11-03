import 'dart:convert';
import 'dart:io';

import 'package:booklet/importing/txt_importer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temp;
  setUp(
    () async => temp = await Directory.systemTemp.createTemp('txt_import_'),
  );
  tearDown(() async => temp.delete(recursive: true));

  Future<String> write(List<int> bytes) async {
    final file = File('${temp.path}/Notes.TXT');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  test(
    'preserves Unicode, indentation, literal markup and line breaks',
    () async {
      final result = await TxtImporter.load(
        await write(
          utf8.encode('\uFEFFHello 🌍\r\n  <b>literal</b>\r\n\r\nNext\rline'),
        ),
      );
      expect(result.title, 'Notes');
      expect(result.blocks.map((b) => b.kind), ['text', 'text']);
      expect(result.blocks.first.delta, [
        {'insert': 'Hello 🌍\n  <b>literal</b>\n'},
      ]);
      expect(result.blocks.last.delta, [
        {'insert': 'Next\nline\n'},
      ]);
    },
  );

  for (final little in [true, false]) {
    test('decodes UTF-16 ${little ? 'LE' : 'BE'} with BOM', () async {
      final units = 'Text 😀 नमस्ते'.codeUnits;
      final result = await TxtImporter.load(
        await write([
          if (little) ...[255, 254] else ...[254, 255],
          for (final unit in units)
            if (little) ...[
              unit & 255,
              unit >> 8,
            ] else ...[
              unit >> 8,
              unit & 255,
            ],
        ]),
      );
      expect(result.blocks.single.delta, [
        {'insert': 'Text 😀 नमस्ते\n'},
      ]);
    });
  }

  test('rejects empty, binary and invalid encoded files', () async {
    for (final bytes in [
      <int>[],
      [32, 10],
      [0, 1, 2],
      [255, 100],
      [255, 254, 0],
    ]) {
      await expectLater(
        TxtImporter.load(await write(bytes)),
        throwsFormatException,
      );
    }
  });

  test('rejects oversized files', () async {
    final path = await write([]);
    final handle = await File(path).open(mode: FileMode.write);
    await handle.truncate(TxtImporter.maxBytes + 1);
    await handle.close();
    await expectLater(TxtImporter.load(path), throwsFormatException);
  });
}
