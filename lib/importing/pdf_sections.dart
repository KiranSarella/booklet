import 'html_importer.dart';

class PdfImportSection {
  const PdfImportSection(this.title, this.blocks);
  final String title;
  final List<HtmlImportBlock> blocks;
}

/// Splits only at the strongest available heading level, keeping subsections
/// and continuation PDF pages inside their chapter.
class PdfSections {
  static String text(HtmlImportBlock block) => (block.delta ?? [])
      .map((op) => op['insert'] is String ? op['insert'] : '')
      .join()
      .trim();

  static List<PdfImportSection> split(
    String title,
    List<List<HtmlImportBlock>> pages,
  ) {
    final blocks = pages.expand((p) => p).toList();
    if (pages.length < 2) return [PdfImportSection(title, blocks)];
    final chapter = RegExp(
      r'^(?:chapter|part|book)\s+(?:\d+|[ivxlcdm]+|one|two|three|four|five|six|seven|eight|nine|ten)\b',
      caseSensitive: false,
    );
    bool explicitChapter(HtmlImportBlock b) {
      final value = text(b);
      return value.length < 160 && chapter.hasMatch(value);
    }

    final hasChapters = blocks.any(explicitChapter);
    // Prefer H1-sized titles when they occur beyond the opening title.
    // Otherwise the next-largest heading style is the chapter-level fallback.
    final hasInternalTitles = blocks.skip(1).any((b) => b.kind == 'title');
    bool boundary(HtmlImportBlock b) =>
        explicitChapter(b) ||
        b.kind == 'title' ||
        (!hasChapters && !hasInternalTitles && b.kind == 'heading');
    final result = <PdfImportSection>[];
    var current = <HtmlImportBlock>[];
    var currentTitle = title;
    void flush() {
      if (current.isNotEmpty) {
        result.add(PdfImportSection(currentTitle, current));
      }
      current = [];
    }

    for (final block in blocks) {
      final heading = text(block);
      if (boundary(block) && heading.isNotEmpty && heading != currentTitle) {
        // A chapter number and its following heading belong together.
        if (current.isNotEmpty && !current.every((b) => boundary(b))) flush();
        if (current.isEmpty) {
          currentTitle = heading;
        } else if (current.every(explicitChapter) && !explicitChapter(block)) {
          currentTitle = '$currentTitle — $heading';
        } else {
          flush();
          currentTitle = heading;
        }
      }
      current.add(block);
    }
    flush();
    if (result.length > 1 || hasChapters) return result;
    // No useful chapter divisions: preserve physical PDF page boundaries.
    return [
      for (var i = 0; i < pages.length; i++)
        if (pages[i].isNotEmpty)
          PdfImportSection('$title — Page ${i + 1}', pages[i]),
    ];
  }
}
