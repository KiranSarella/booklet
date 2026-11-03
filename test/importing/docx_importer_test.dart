import 'dart:io';

import 'package:archive/archive.dart';
import 'package:booklet/importing/docx_importer.dart';
import 'package:flutter_test/flutter_test.dart';

const word = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
const rel =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

void main() {
  late Directory temp;
  setUp(
    () async => temp = await Directory.systemTemp.createTemp('docx_import_'),
  );
  tearDown(() async => temp.delete(recursive: true));

  Future<String> book(
    String body, {
    bool metadata = true,
    bool missing = false,
  }) async {
    final archive = Archive();
    if (!missing) {
      archive.addFile(
        ArchiveFile.string('word/document.xml', '''
<w:document xmlns:w="$word" xmlns:r="$rel" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
<w:body>$body</w:body></w:document>'''),
      );
    }
    archive.addFile(
      ArchiveFile.string(
        'word/styles.xml',
        '''
<w:styles xmlns:w="$word"><w:style w:styleId="CustomHeading"><w:name w:val="Heading 2"/></w:style></w:styles>''',
      ),
    );
    archive.addFile(
      ArchiveFile.string('word/numbering.xml', '''
<w:numbering xmlns:w="$word">
<w:abstractNum w:abstractNumId="0"><w:lvl w:ilvl="0"><w:start w:val="3"/><w:numFmt w:val="decimal"/></w:lvl><w:lvl w:ilvl="1"><w:numFmt w:val="bullet"/></w:lvl></w:abstractNum>
<w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num></w:numbering>'''),
    );
    archive.addFile(
      ArchiveFile.string('word/_rels/document.xml.rels', '''
<Relationships><Relationship Id="link" Target="https://example.com/guide?a=1&amp;b=2" TargetMode="External"/>
<Relationship Id="image" Target="media/pic.png"/>
<Relationship Id="bad" Target="../../escape.png"/></Relationships>'''),
    );
    archive.addFile(ArchiveFile.string('word/media/pic.png', 'image data'));
    archive.addFile(ArchiveFile.string('../escape.png', 'bad'));
    if (metadata) {
      archive.addFile(
        ArchiveFile.string(
          'docProps/core.xml',
          '<core><title>Document title</title></core>',
        ),
      );
    }
    final file = File('${temp.path}/Report.docx');
    await file.writeAsBytes(ZipEncoder().encode(archive));
    return file.path;
  }

  test(
    'imports headings, run formatting, hyperlinks, breaks and table text',
    () async {
      final result = await DocxImporter.load(
        await book(
          '''
<w:p><w:pPr><w:pStyle w:val="CustomHeading"/></w:pPr><w:r><w:t>Heading</w:t></w:r></w:p>
<w:p><w:r><w:rPr><w:b/><w:i/><w:u w:val="single"/><w:strike/></w:rPr><w:t>Styled</w:t></w:r><w:r><w:rPr><w:b w:val="0"/></w:rPr><w:t> plain</w:t><w:br/><w:t>line</w:t></w:r><w:hyperlink r:id="link"><w:r><w:t>Link</w:t></w:r></w:hyperlink><w:del><w:r><w:t>Deleted</w:t></w:r></w:del></w:p>
<w:tbl><w:tr><w:tc><w:p><w:r><w:t>Cell A</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>Cell B</w:t></w:r></w:p></w:tc></w:tr></w:tbl>''',
        ),
        assetRoot: temp,
      );
      expect(result.title, 'Document title');
      expect(result.blocks.map((b) => b.kind), [
        'heading',
        'text',
        'text',
        'text',
      ]);
      expect(
        result.blocks[1].delta,
        contains(
          equals({
            'insert': 'Styled',
            'attributes': {
              'bold': true,
              'italic': true,
              'underline': true,
              'strike': true,
            },
          }),
        ),
      );
      expect(
        result.blocks[1].delta,
        contains(
          equals({
            'insert': 'Link',
            'attributes': {'link': 'https://example.com/guide?a=1&b=2'},
          }),
        ),
      );
      expect(result.blocks[1].delta.toString(), isNot(contains('Deleted')));
      expect(result.blocks[2].delta, [
        {'insert': 'Cell A'},
        {'insert': '\n'},
      ]);
      expect(result.blocks[3].delta, [
        {'insert': 'Cell B'},
        {'insert': '\n'},
      ]);
    },
  );

  test('imports list numbering and nested bullet depth', () async {
    String item(String text, int depth) =>
        '<w:p><w:pPr><w:numPr><w:ilvl w:val="$depth"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>$text</w:t></w:r></w:p>';
    final result = await DocxImporter.load(
      await book('${item('Third', 0)}${item('Bullet', 1)}${item('Fourth', 0)}'),
      assetRoot: temp,
    );
    expect(result.blocks.map((b) => b.kind), [
      'numbered_list',
      'bulleted_list',
      'numbered_list',
    ]);
    expect(result.blocks.map((b) => b.number), [3, null, 4]);
    expect(result.blocks[1].depth, 1);
  });

  test(
    'persists embedded images without extracting arbitrary archive paths',
    () async {
      final result = await DocxImporter.load(
        await book(
          '''<w:p><w:r><w:drawing><a:blip r:embed="image"/></w:drawing></w:r></w:p>''',
          metadata: false,
        ),
        assetRoot: temp,
      );
      expect(result.title, 'Report');
      expect(result.blocks.single.kind, 'image');
      expect(
        await File.fromUri(Uri.parse(result.blocks.single.source!))
            .readAsString(),
        'image data',
      );
      expect(
        temp.listSync().whereType<Directory>().single.listSync().length,
        1,
      );
    },
  );

  test('rejects missing body content and invalid Word files', () async {
    await expectLater(
      DocxImporter.load(await book('', missing: true), assetRoot: temp),
      throwsFormatException,
    );
    await expectLater(
      DocxImporter.load(await book('<w:p/>'), assetRoot: temp),
      throwsFormatException,
    );
  });
}
