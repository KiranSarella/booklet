import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/importing/html_importer.dart';
import 'package:booklet/importing/pdf_importer.dart';
import 'package:booklet/importing/pdf_sections.dart';
import 'package:booklet/importing/pdf_layout.dart';
import 'package:booklet/ui/detail/editor/editor_vm.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

HtmlImportBlock block(String kind, String text) => HtmlImportBlock(
  kind,
  delta: [
    {'insert': '$text\n'},
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('detects H1-sized chapter starts on later physical PDF pages', () async {
    PdfLayoutPage page(String heading) => PdfLayoutPage([
      PdfGlyph(heading, 0, 0, 200, 24, 24, bold: true),
      const PdfGlyph(
        'Ordinary body text with enough characters to establish the document font size.',
        0,
        60,
        400,
        72,
        12,
      ),
    ], []);
    final result = await PdfImporter.fromLayout([
      page('Book'),
      page('Installation'),
      page('Usage'),
    ], fileName: 'book.pdf');
    expect(result.sections.map((s) => s.title), [
      'Book',
      'Installation',
      'Usage',
    ]);
    expect(
      result.sections.every((s) => s.blocks.first.kind == 'title'),
      isTrue,
    );
  });

  test('keeps continuation pages and subsections inside their chapter', () {
    final pages = [
      [block('title', 'Book'), block('text', 'Preface')],
      [
        block('heading', 'Chapter 1'),
        block('text', 'Beginning'),
        block('subheading', 'Details'),
      ],
      [
        block('text', 'Continuation'),
        HtmlImportBlock('image', source: '/tmp/figure.png'),
      ],
      [block('heading', 'Chapter 2'), block('text', 'Ending')],
    ];
    final sections = PdfSections.split('Book', pages);
    expect(sections.map((s) => s.title), ['Book', 'Chapter 1', 'Chapter 2']);
    expect(sections[1].blocks.length, 5);
    expect(
      sections.expand((s) => s.blocks),
      orderedEquals(pages.expand((p) => p)),
    );
  });

  test('splits H1s without splitting subheadings', () {
    final sections = PdfSections.split('Guide', [
      [block('title', 'Introduction'), block('text', 'First')],
      [
        block('heading', 'Installation'),
        block('subheading', 'Linux'),
        block('text', 'Steps'),
      ],
      [block('heading', 'Usage'), block('text', 'Last')],
    ]);
    expect(sections.map((s) => s.title), [
      'Introduction',
      'Installation',
      'Usage',
    ]);
    expect(sections[1].blocks.length, 3);
  });

  test('prefers H1 boundaries over smaller headings', () {
    final sections = PdfSections.split('Book', [
      [block('title', 'Book'), block('text', 'Preface')],
      [
        block('title', 'Installation'),
        block('heading', 'Dependencies'),
        block('text', 'Steps'),
      ],
      [
        block('title', 'Usage'),
        block('heading', 'Examples'),
        block('text', 'Body'),
      ],
    ]);
    expect(sections.map((s) => s.title), ['Book', 'Installation', 'Usage']);
    expect(sections[1].blocks.length, 3);
  });

  test('falls back to original PDF pages and preserves image-only pages', () {
    final pages = [
      [block('text', 'First')],
      <HtmlImportBlock>[],
      [HtmlImportBlock('image', source: '/tmp/scan.png')],
    ];
    final sections = PdfSections.split('Scans', pages);
    expect(sections.map((s) => s.title), ['Scans — Page 1', 'Scans — Page 3']);
    expect(sections.last.blocks.single.kind, 'image');
    expect(PdfSections.split('Single', [pages.first]).single.title, 'Single');
  });

  test(
    'keeps a chapter label and adjacent title together across PDF pages',
    () {
      final sections = PdfSections.split('Book', [
        [block('heading', 'Chapter 1')],
        [block('title', 'A beginning'), block('text', 'Body')],
      ]);
      expect(sections.single.title, 'Chapter 1 — A beginning');
      expect(sections.single.blocks.length, 3);
    },
  );

  test(
    'imports a group atomically, selects its first page and respects read only',
    () {
      final settings = DocumentSettingsController();
      final theme = PageSettingsController(settings);
      final vm = EditorVM(theme);
      addTearDown(() {
        vm.dispose();
        theme.dispose();
        settings.dispose();
      });
      final original = vm.selectedPage!.id;
      final result = PdfImportResult(
        'Book',
        ['page 1', 'page 2'],
        sections: [
          PdfImportSection('Chapter 1', [
            block('title', 'Chapter 1'),
            block('text', 'First'),
          ]),
          PdfImportSection('Chapter 2', [
            block('title', 'Chapter 2'),
            block('text', 'Second'),
          ]),
        ],
      );
      vm.importPdf(result);
      expect(vm.loadedPages.length, 3);
      expect(vm.loadedPages.any((p) => p.id == original), isTrue);
      final group = vm.navigation.groups.last;
      expect(group.isGroup, isTrue);
      expect(group.title, 'Book');
      expect(group.children.map((n) => n.title), ['Chapter 1', 'Chapter 2']);
      expect(vm.selectedPage!.id, group.children.first.pageId);
      expect(vm.selectedPage!.components.length, 2);
      final groups = vm.navigation.groups.length;
      settings.updateEditMode(DocumentEditMode.readOnly);
      vm.importPdf(result);
      expect(vm.loadedPages.length, 3);
      expect(vm.navigation.groups.length, groups);
    },
  );
}
