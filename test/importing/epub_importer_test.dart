import 'dart:io';

import 'package:archive/archive.dart';
import 'package:booklet/importing/epub_importer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temp;
  setUp(() async => temp = await Directory.systemTemp.createTemp('epub_test_'));
  tearDown(() async => temp.delete(recursive: true));

  Future<String> book({bool unsafe = false, bool missing = false}) async {
    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          'META-INF/container.xml',
          '<container><rootfiles><rootfile full-path="OPS/book.opf"/></rootfiles></container>',
        ),
      )
      ..addFile(
        ArchiveFile.string(
          'OPS/book.opf',
          '''
<package><metadata><title>My book</title></metadata><manifest>
<item id="a" href="a.xhtml" media-type="application/xhtml+xml"/>
<item id="b" href="b.xhtml" media-type="application/xhtml+xml"/>
</manifest><spine><itemref idref="b"/><itemref idref="a"/></spine></package>''',
        ),
      )
      ..addFile(
        ArchiveFile.string(
          'OPS/a.xhtml',
          '<h1>First</h1><p>Hello <b>world</b>.</p>',
        ),
      )
      ..addFile(ArchiveFile.string('OPS/images/pic.png', 'image'));
    if (!missing) {
      archive.addFile(
        ArchiveFile.string(
          'OPS/b.xhtml',
          '<h1>Second</h1><p>Picture</p><img src="images/pic.png"/>',
        ),
      );
    }
    if (unsafe) archive.addFile(ArchiveFile.string('../escape', 'bad'));
    final file = File('${temp.path}/book.epub');
    await file.writeAsBytes(ZipEncoder().encode(archive));
    return file.path;
  }

  test(
    'imports spine order, formatting and persistent relative images',
    () async {
      final result = await EpubImporter.load(await book(), assetRoot: temp);
      expect(result.title, 'My book');
      expect(result.chapters.map((c) => c.title), ['Second', 'First']);
      final image = result.chapters.first.blocks.firstWhere(
        (b) => b.kind == 'image',
      );
      expect(
        await File.fromUri(Uri.parse(image.source!)).readAsString(),
        'image',
      );
      expect(
        result.chapters.last.blocks.last.delta,
        contains(
          equals({
            'insert': 'world',
            'attributes': {'bold': true},
          }),
        ),
      );
    },
  );

  test('rejects archive traversal before extracting', () async {
    final path = await book(unsafe: true);
    await expectLater(
      EpubImporter.load(path, assetRoot: temp),
      throwsFormatException,
    );
    expect(temp.listSync().length, 1);
  });

  test('missing chapters fail and remove extracted assets', () async {
    final path = await book(missing: true);
    await expectLater(
      EpubImporter.load(path, assetRoot: temp),
      throwsFormatException,
    );
    expect(temp.listSync().length, 1);
  });
}
