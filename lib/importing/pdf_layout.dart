import 'dart:math' as math;
import 'dart:typed_data';

import 'package:booklet/importing/html_importer.dart';

/// PDF coordinates normalized to a top-left origin, measured in points.
class PdfGlyph {
  const PdfGlyph(
    this.text,
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.size, {
    this.bold = false,
    this.italic = false,
  });
  final String text;
  final double left, top, right, bottom, size;
  final bool bold, italic;
}

class PdfLayoutImage {
  const PdfLayoutImage(this.left, this.top, this.right, this.bottom, this.png);
  final double left, top, right, bottom;
  final Uint8List png;
}

class PdfLayoutPage {
  const PdfLayoutPage(this.glyphs, this.images);
  final List<PdfGlyph> glyphs;
  final List<PdfLayoutImage> images;
}

class PdfLayoutBlock {
  PdfLayoutBlock(this.left, this.top, this.right, this.bottom, this.block);
  double left, top, right, bottom;
  final HtmlImportBlock block;
}

class PdfLayout {
  /// Character-weighted mode avoids a large title skewing the body font size.
  static double bodySize(List<PdfLayoutPage> pages) {
    final sizes = <int, int>{};
    for (final page in pages) {
      for (final glyph in page.glyphs) {
        if (glyph.text.trim().isEmpty || glyph.size <= 0) continue;
        final size = glyph.size.round();
        sizes[size] = (sizes[size] ?? 0) + glyph.text.length;
      }
    }
    return sizes.isEmpty
        ? 12
        : sizes.entries
              .reduce((a, b) => a.value >= b.value ? a : b)
              .key
              .toDouble();
  }

  static List<PdfLayoutBlock> textBlocks(
    PdfLayoutPage page,
    double body, {
    required bool firstPage,
  }) {
    final lines = <List<PdfGlyph>>[];
    var current = <PdfGlyph>[];
    void flush() {
      if (current.any((g) => g.text.trim().isNotEmpty)) lines.add(current);
      current = [];
    }

    for (final glyph in page.glyphs) {
      if (glyph.text == '\r' || glyph.text == '\n') {
        flush();
        continue;
      }
      if (current.isNotEmpty && glyph.text.trim().isNotEmpty) {
        final prev = current.last;
        if ((glyph.bottom - prev.bottom).abs() >
                math.max(glyph.size, prev.size) * .55 ||
            glyph.left < prev.left - glyph.size ||
            glyph.left - prev.right > math.max(glyph.size, prev.size) * 2.5) {
          flush();
        }
      }
      current.add(glyph);
    }
    flush();
    final result = <PdfLayoutBlock>[];
    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex];
      while (line.isNotEmpty && line.first.text.trim().isEmpty) {
        line.removeAt(0);
      }
      while (line.isNotEmpty && line.last.text.trim().isEmpty) {
        line.removeLast();
      }
      final size = line.map((g) => g.size).reduce(math.max);
      final text = line.map((g) => g.text).join();
      final short = text.length < 160;
      final top = line.map((g) => g.top).reduce(math.min);
      final bottom = line.map((g) => g.bottom).reduce(math.max);
      final gapBefore = lineIndex == 0
          ? double.infinity
          : top - lines[lineIndex - 1].map((g) => g.bottom).reduce(math.max);
      final gapAfter = lineIndex + 1 == lines.length
          ? double.infinity
          : lines[lineIndex + 1].map((g) => g.top).reduce(math.min) - bottom;
      final boldHeading =
          text.length < 120 &&
          size >= body * .95 &&
          line.where((g) => g.text.trim().isNotEmpty).every((g) => g.bold) &&
          gapBefore > body * .65 &&
          gapAfter > body * .5;
      final kind = short && (size >= body * 1.18 || boldHeading)
          ? (firstPage &&
                    (size >= body * 1.65 || (lineIndex == 0 && boldHeading))
                ? 'title'
                : size >= body * 1.4
                ? 'heading'
                : 'subheading')
          : 'text';
      final delta = <Map<String, dynamic>>[];
      for (var i = 0; i < line.length; i++) {
        final g = line[i];
        // Some PDFs position words without inserting actual space characters.
        if (i > 0 &&
            g.text.trim().isNotEmpty &&
            line[i - 1].text.trim().isNotEmpty &&
            g.left - line[i - 1].right > g.size * .18) {
          delta.add({'insert': ' '});
        }
        final attributes = <String, dynamic>{
          if (g.bold) 'bold': true,
          if (g.italic) 'italic': true,
        };
        if (delta.isNotEmpty &&
            delta.last['attributes']?['bold'] == attributes['bold'] &&
            delta.last['attributes']?['italic'] == attributes['italic']) {
          delta.last['insert'] = '${delta.last['insert']}${g.text}';
        } else {
          delta.add({
            'insert': g.text,
            if (attributes.isNotEmpty) 'attributes': attributes,
          });
        }
      }
      delta.add({'insert': '\n'});
      result.add(
        PdfLayoutBlock(
          line.map((g) => g.left).reduce(math.min),
          top,
          line.map((g) => g.right).reduce(math.max),
          bottom,
          HtmlImportBlock(kind, delta: delta),
        ),
      );
    }
    return result;
  }

  /// Recursive whitespace cuts put full-width titles first and read columns
  /// top-to-bottom. Falls back to vertical position in overlapping layouts.
  static List<PdfLayoutBlock> readingOrder(
    List<PdfLayoutBlock> items,
    double body,
  ) {
    if (items.length < 2) return items;
    for (final horizontal in [true, false]) {
      final sorted = [...items]
        ..sort(
          (a, b) => (horizontal ? a.top : a.left).compareTo(
            horizontal ? b.top : b.left,
          ),
        );
      var end = horizontal ? sorted.first.bottom : sorted.first.right;
      for (var i = 1; i < sorted.length; i++) {
        final start = horizontal ? sorted[i].top : sorted[i].left;
        if (start - end > body * (horizontal ? .8 : 2)) {
          return [
            ...readingOrder(sorted.sublist(0, i), body),
            ...readingOrder(sorted.sublist(i), body),
          ];
        }
        end = math.max(end, horizontal ? sorted[i].bottom : sorted[i].right);
      }
    }
    return [...items]..sort((a, b) {
      final vertical = a.top.compareTo(b.top);
      return vertical == 0 ? a.left.compareTo(b.left) : vertical;
    });
  }

  static List<HtmlImportBlock> paragraphs(
    List<PdfLayoutBlock> ordered,
    double body,
  ) {
    final result = <HtmlImportBlock>[];
    PdfLayoutBlock? previous;
    for (final item in ordered) {
      final p = previous;
      final merge =
          p != null &&
          p.block.kind == 'text' &&
          item.block.kind == 'text' &&
          item.top >= p.bottom - body * .2 &&
          item.top - p.bottom < body * .65 &&
          (item.left - p.left).abs() < body &&
          item.left < p.right &&
          item.right > p.left;
      if (merge) {
        // Keep meaningful line breaks inside a paragraph, rather than flattening.
        result.last.delta!.addAll(item.block.delta!);
      } else {
        result.add(item.block);
      }
      previous = item;
    }
    return result;
  }
}
