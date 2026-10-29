import 'dart:io';

import 'package:pdfrx/pdfrx.dart';
import 'package:path_provider/path_provider.dart';

import 'html_importer.dart';
import 'pdf_layout.dart';
import 'pdf_native_extractor.dart';
import 'pdf_sections.dart';
export 'pdf_sections.dart' show PdfImportSection;

class PdfImportResult {
  const PdfImportResult(
    this.title,
    this.pages, {
    this.blocks = const [],
    this.sections = const [],
  });

  final String title;
  final List<String> pages;
  final List<HtmlImportBlock> blocks;
  final List<PdfImportSection> sections;
}

/// Reconstructs editable content from PDF text geometry and embedded images.
class PdfImporter {
  static const maxBytes = 50 * 1024 * 1024;

  static Future<PdfImportResult> load(
    String path, {
    Directory? imageRoot,
  }) async {
    if (await File(path).length() > maxBytes) {
      throw const FormatException('PDF file is too large (maximum 50 MB).');
    }
    await pdfrxFlutterInitialize(processWidePdfiumGate: true);
    final document = await PdfDocument.openFile(path);
    try {
      final pages = <PdfLayoutPage>[];
      for (var i = 0; i < document.pages.length; i++) {
        pages.add(
          await document.useNativeDocumentHandle(
            (handle) => PdfNativeExtractor.read(
              handle,
              i,
              modulePath: Pdfrx.pdfiumModulePath,
            ),
          ),
        );
      }
      return await fromLayout(
        pages,
        fileName: Uri.file(path).pathSegments.last,
        imageRoot: imageRoot,
      );
    } finally {
      await document.dispose();
    }
  }

  static Future<PdfImportResult> fromLayout(
    List<PdfLayoutPage> pages, {
    required String fileName,
    Directory? imageRoot,
  }) async {
    final body = PdfLayout.bodySize(pages);
    final blocks = <HtmlImportBlock>[];
    final pageBlocks = <List<HtmlImportBlock>>[];
    Directory? images;
    try {
      for (var i = 0; i < pages.length; i++) {
        final page = pages[i];
        final positioned = PdfLayout.textBlocks(page, body, firstPage: i == 0);
        for (final image in page.images) {
          if (images == null) {
            final root =
                imageRoot ??
                Directory(
                  '${(await getApplicationSupportDirectory()).path}/pdf_imports',
                );
            await root.create(recursive: true);
            images = await root.createTemp('import_');
          }
          final target = File(
            '${images.path}/image_${i}_${positioned.length}.png',
          );
          await target.writeAsBytes(image.png);
          positioned.add(
            PdfLayoutBlock(
              image.left,
              image.top,
              image.right,
              image.bottom,
              HtmlImportBlock('image', source: target.path),
            ),
          );
        }
        final content = PdfLayout.paragraphs(
          PdfLayout.readingOrder(positioned, body),
          body,
        );
        pageBlocks.add(content);
        blocks.addAll(content);
      }
      if (blocks.isEmpty) {
        throw const FormatException('This PDF has no extractable content.');
      }
      final titleBlock = blocks.where((b) => b.kind == 'title').firstOrNull;
      final title = titleBlock == null
          ? _fileTitle(fileName)
          : titleBlock.delta!.map((op) => op['insert'] as String).join().trim();
      return PdfImportResult(
        title,
        [for (final page in pages) page.glyphs.map((g) => g.text).join()],
        blocks: blocks,
        sections: PdfSections.split(title, pageBlocks),
      );
    } catch (_) {
      if (images != null) await images.delete(recursive: true);
      rethrow;
    }
  }

  static String _fileTitle(String fileName) {
    final title = fileName
        .replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '')
        .trim();
    return title.isEmpty ? 'Imported PDF' : title;
  }

  static PdfImportResult fromText(
    List<String> pages, {
    required String fileName,
  }) {
    final text = pages
        .map(
          (page) => page
              .replaceAll('\r\n', '\n')
              .replaceAll('\r', '\n')
              .replaceAll('\u0000', '')
              .trim(),
        )
        .where((page) => page.isNotEmpty)
        .toList();
    if (text.isEmpty) {
      throw const FormatException(
        'This PDF has no extractable text. Scanned PDFs need OCR before importing.',
      );
    }
    final title = fileName
        .replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '')
        .trim();
    return PdfImportResult(title.isEmpty ? 'Imported PDF' : title, text);
  }
}
