import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/storage/booklet_file.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/detail/editor/editor_vm.dart';

import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:booklet/importing/html_importer.dart';
import 'package:booklet/importing/pdf_importer.dart';
import 'package:booklet/importing/pdf_layout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:pdfrx/pdfrx.dart';

String text(HtmlImportBlock block) =>
    block.delta!.map((op) => op['insert']).join();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('extracts headings, paragraphs, inline styles and images from an actual PDF', () async {
    final directory = await Directory.systemTemp.createTemp('pdf_import_test_');
    addTearDown(() => directory.delete(recursive: true));
    Pdfrx.cacheDirectoryPath = directory.path;
    // Flutter test does not expose its native-assets manifest to the PDFium
    // loader on macOS. Use the binary already produced by the build hook.
    if (Platform.isMacOS) {
      final binaries =
          Directory('.dart_tool/hooks_runner/shared/pdfium_dart/build')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('/libpdfium.dylib'));
      Pdfrx.pdfiumModulePath = binaries.first.absolute.path;
    }
    final result = await PdfImporter.load(
      'test/fixtures/layout_import.pdf',
      imageRoot: directory,
    );
    expect(result.title, 'PDF Import Guide');
    expect(result.blocks.first.kind, 'title');
    expect(
      result.blocks.where((b) => b.kind == 'heading').map(text),
      contains('Getting started\n'),
    );
    final paragraph = result.blocks.firstWhere(
      (b) => b.delta != null && text(b).startsWith('This paragraph'),
    );
    expect(text(paragraph), contains('\nThis is its second line'));
    final separate = result.blocks.firstWhere(
      (b) => b.delta != null && text(b).startsWith('A separate'),
    );
    expect(
      separate.delta!
          .where((op) => op['attributes']?['bold'] == true)
          .map((op) => op['insert'])
          .join(),
      'bold text',
    );
    expect(
      separate.delta!
          .where((op) => op['attributes']?['italic'] == true)
          .map((op) => op['insert'])
          .join(),
      'italic text.',
    );
    final images = result.blocks.where((b) => b.kind == 'image').toList();
    expect(images.length, 2); // Includes the image-only second page.
    for (final block in images) {
      expect(
        image.decodePng(await File(block.source!).readAsBytes()),
        isNotNull,
      );
    }
    final firstImage = result.blocks.indexOf(images.first);
    expect(text(result.blocks[firstImage + 1]), 'A caption below the image.\n');
    final settings = DocumentSettingsController();
    final theme = PageSettingsController(settings);
    final vm = EditorVM(theme);
    addTearDown(() {
      vm.dispose();
      theme.dispose();
      settings.dispose();
    });
    vm.importPdf(result);
    expect(vm.components.first.component.def.key, 'title');
    final package = '${directory.path}/saved.booklet';
    await BookletFile.savePage(package, vm.selectedPage!);
    // The saved document must own its images, independent of the import cache.
    for (final block in images) {
      await File(block.source!).delete();
    }
    final restored = await BookletFile.loadPage(
      package,
      vm.selectedPage!.id,
      theme,
    );
    addTearDown(restored.dispose);
    final restoredImages = restored.components
        .map((c) => c.component.state)
        .whereType<ImageComponentState>();
    expect(restoredImages.length, 2);
    for (final state in restoredImages) {
      expect(
        image.decodePng(await File(state.mediaPath!).readAsBytes()),
        isNotNull,
      );
    }
  });

  test('recognizes isolated bold headings at body size and inserts positioned spaces', () {
    final page = PdfLayoutPage([
      const PdfGlyph('Title', 0, 0, 100, 12, 12, bold: true),
      const PdfGlyph(
        'An ordinary paragraph with many words.',
        0,
        32,
        300,
        44,
        12,
      ),
      const PdfGlyph('Section', 0, 80, 100, 92, 12, bold: true),
      const PdfGlyph(
        'Another ordinary paragraph with many words.',
        0,
        112,
        300,
        124,
        12,
      ),
    ], []);
    final blocks = PdfLayout.textBlocks(
      page,
      PdfLayout.bodySize([page]),
      firstPage: true,
    );
    expect(blocks.map((b) => b.block.kind), [
      'title',
      'text',
      'subheading',
      'text',
    ]);
    final spaced = PdfLayout.textBlocks(
      const PdfLayoutPage([
        PdfGlyph('Hello', 0, 0, 25, 10, 10),
        PdfGlyph('world', 30, 0, 55, 10, 10),
      ], []),
      10,
      firstPage: false,
    );
    expect(text(spaced.single.block), 'Hello world\n');
  });

  test('reads each column in order after a spanning title', () {
    PdfLayoutBlock block(String value, double x, double y, double right) =>
        PdfLayoutBlock(
          x,
          y,
          right,
          y + 10,
          HtmlImportBlock(
            'text',
            delta: [
              {'insert': '$value\n'},
            ],
          ),
        );
    final ordered = PdfLayout.readingOrder([
      block('title', 10, 0, 300),
      block('left 1', 10, 40, 120),
      block('right 1', 180, 40, 300),
      block('left 2', 10, 55, 120),
      block('right 2', 180, 55, 300),
    ], 12);
    expect(ordered.map((b) => text(b.block).trim()), [
      'title',
      'left 1',
      'left 2',
      'right 1',
      'right 2',
    ]);
  });
}
