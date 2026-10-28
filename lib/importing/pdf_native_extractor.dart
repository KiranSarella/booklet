import 'dart:ffi';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:image/image.dart' as image;
import 'package:pdfium_dart/pdfium_dart.dart' as pdf;

import 'pdf_layout.dart';

/// Called only while pdfrx suspends its worker and owns the document lifetime.
class PdfNativeExtractor {
  static PdfLayoutPage read(int handle, int index, {String? modulePath}) {
    // useNativeDocumentHandle already holds the process-wide PDFium gate.
    return _read(
      pdf.getPdfium(modulePath: modulePath),
      Pointer.fromAddress(handle),
      index,
    );
  }

  static PdfLayoutPage _read(pdf.PDFium api, pdf.FPDF_DOCUMENT doc, int index) {
    final page = api.FPDF_LoadPage(doc, index);
    if (page == nullptr) {
      throw const FormatException('Could not read a PDF page.');
    }
    try {
      final coordinates = _PageCoordinates(api, page);
      try {
        final glyphs = <PdfGlyph>[];
        final text = api.FPDFText_LoadPage(page);
        if (text != nullptr) {
          final box = calloc<Double>(4);
          final flags = calloc<Int>();
          final fontName = calloc<Uint8>(256);
          try {
            for (var i = 0; i < api.FPDFText_CountChars(text); i++) {
              final unicode = api.FPDFText_GetUnicode(text, i);
              if (unicode == 0 || unicode > 0x10ffff) continue;
              if (unicode == 10 || unicode == 13) {
                glyphs.add(
                  PdfGlyph(String.fromCharCode(unicode), 0, 0, 0, 0, 0),
                );
                continue;
              }
              if (api.FPDFText_GetCharBox(
                    text,
                    i,
                    box,
                    box + 1,
                    box + 2,
                    box + 3,
                  ) ==
                  0) {
                continue;
              }
              flags.value = 0;
              fontName[0] = 0;
              final nameLength = api.FPDFText_GetFontInfo(
                text,
                i,
                fontName.cast(),
                256,
                flags,
              );
              final name = nameLength > 0 && nameLength <= 256
                  ? String.fromCharCodes(
                      fontName.asTypedList(nameLength).takeWhile((c) => c != 0),
                    ).toLowerCase()
                  : '';

              final rect = coordinates.rect(box[0], box[2], box[1], box[3]);
              glyphs.add(
                PdfGlyph(
                  String.fromCharCode(unicode),
                  rect[0],
                  rect[1],
                  rect[2],
                  rect[3],
                  api.FPDFText_GetFontSize(text, i),
                  bold:
                      api.FPDFText_GetFontWeight(text, i) >= 600 ||
                      (flags.value & (1 << 18)) != 0 ||
                      RegExp('bold|black|demi|semibold').hasMatch(name),
                  italic:
                      (flags.value & (1 << 6)) != 0 ||
                      RegExp('italic|oblique').hasMatch(name),
                ),
              );
            }
          } finally {
            calloc.free(box);
            calloc.free(flags);
            calloc.free(fontName);
            api.FPDFText_ClosePage(text);
          }
        }
        final images = <PdfLayoutImage>[];
        void visit(pdf.FPDF_PAGEOBJECT object, int depth, List<double> matrix) {
          if (depth > 20) return;
          final type = api.FPDFPageObj_GetType(object);
          if (type == pdf.FPDF_PAGEOBJ_FORM) {
            final m = calloc<pdf.FS_MATRIX>();
            try {
              if (api.FPDFPageObj_GetMatrix(object, m) == 0) return;
              final v = m.ref;
              final local = [v.a, v.b, v.c, v.d, v.e, v.f];
              final combined = _multiply(matrix, local);
              for (var i = 0; i < api.FPDFFormObj_CountObjects(object); i++) {
                visit(
                  api.FPDFFormObj_GetObject(object, i),
                  depth + 1,
                  combined,
                );
              }
            } finally {
              calloc.free(m);
            }
          } else if (type == pdf.FPDF_PAGEOBJ_IMAGE) {
            final bounds = calloc<Float>(4);
            try {
              if (api.FPDFPageObj_GetBounds(
                    object,
                    bounds,
                    bounds + 1,
                    bounds + 2,
                    bounds + 3,
                  ) ==
                  0) {
                return;
              }
              final points = [
                for (final x in [bounds[0], bounds[2]])
                  for (final y in [bounds[1], bounds[3]])
                    (
                      matrix[0] * x + matrix[2] * y + matrix[4],
                      matrix[1] * x + matrix[3] * y + matrix[5],
                    ),
              ];
              // Bound output allocation before asking PDFium to rasterize an object.
              if ((bounds[2] - bounds[0]).abs() *
                      (bounds[3] - bounds[1]).abs() >
                  16000000) {
                throw const FormatException(
                  'A PDF image is too large to import safely.',
                );
              }
              final bitmap = api.FPDFImageObj_GetRenderedBitmap(
                doc,
                page,
                object,
              );
              if (bitmap == nullptr) {
                throw const FormatException('Could not extract a PDF image.');
              }
              try {
                final png = _png(api, bitmap);
                final rect = coordinates.rect(
                  points.map((p) => p.$1).reduce(math.min),
                  points.map((p) => p.$2).reduce(math.min),
                  points.map((p) => p.$1).reduce(math.max),
                  points.map((p) => p.$2).reduce(math.max),
                );
                images.add(
                  PdfLayoutImage(rect[0], rect[1], rect[2], rect[3], png),
                );
              } finally {
                api.FPDFBitmap_Destroy(bitmap);
              }
            } finally {
              calloc.free(bounds);
            }
          }
        }

        for (var i = 0; i < api.FPDFPage_CountObjects(page); i++) {
          visit(api.FPDFPage_GetObject(page, i), 0, [1, 0, 0, 1, 0, 0]);
        }
        return PdfLayoutPage(glyphs, images);
      } finally {
        coordinates.dispose();
      }
    } finally {
      api.FPDF_ClosePage(page);
    }
  }

  static List<double> _multiply(List<double> a, List<double> b) => [
    a[0] * b[0] + a[2] * b[1],
    a[1] * b[0] + a[3] * b[1],
    a[0] * b[2] + a[2] * b[3],
    a[1] * b[2] + a[3] * b[3],
    a[0] * b[4] + a[2] * b[5] + a[4],
    a[1] * b[4] + a[3] * b[5] + a[5],
  ];

  static Uint8List _png(pdf.PDFium api, pdf.FPDF_BITMAP bitmap) {
    final width = api.FPDFBitmap_GetWidth(bitmap),
        height = api.FPDFBitmap_GetHeight(bitmap);
    if (width <= 0 || height <= 0 || width * height > 16000000) {
      throw const FormatException('A PDF image is too large to import safely.');
    }
    final format = api.FPDFBitmap_GetFormat(bitmap);
    final stride = api.FPDFBitmap_GetStride(bitmap);
    final buffer = api.FPDFBitmap_GetBuffer(bitmap)
        .cast<Uint8>()
        .asTypedList(stride * height);
    final channels = format == pdf.FPDFBitmap_Gray
        ? 1
        : format == pdf.FPDFBitmap_BGR
        ? 3
        : 4;
    final output = image.Image(width: width, height: height, numChannels: 4);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final offset = y * stride + x * channels;
        final alpha =
            format == pdf.FPDFBitmap_BGRA ||
                format == pdf.FPDFBitmap_BGRA_Premul
            ? buffer[offset + 3]
            : 255;
        int color(int channel) {
          final value = buffer[offset + (channels == 1 ? 0 : channel)];
          return format == pdf.FPDFBitmap_BGRA_Premul && alpha > 0
              ? (value * 255 ~/ alpha).clamp(0, 255)
              : value;
        }

        output.setPixelRgba(x, y, color(2), color(1), color(0), alpha);
      }
    }
    return image.encodePng(output);
  }
}

/// PDFium applies page rotation and crop-box offsets when mapping coordinates.
class _PageCoordinates {
  _PageCoordinates(this.api, this.page)
    : width = (api.FPDF_GetPageWidth(page) * 100).round(),
      height = (api.FPDF_GetPageHeight(page) * 100).round();
  final pdf.PDFium api;
  final pdf.FPDF_PAGE page;
  final int width, height;
  final Pointer<Int> output = calloc<Int>(4);

  List<double> rect(double left, double bottom, double right, double top) {
    if (api.FPDF_PageToDevice(
              page,
              0,
              0,
              width,
              height,
              0,
              left,
              bottom,
              output,
              output + 1,
            ) ==
            0 ||
        api.FPDF_PageToDevice(
              page,
              0,
              0,
              width,
              height,
              0,
              right,
              top,
              output + 2,
              output + 3,
            ) ==
            0) {
      throw const FormatException('Could not read PDF page coordinates.');
    }
    return [
      math.min(output[0], output[2]) / 100,
      math.min(output[1], output[3]) / 100,
      math.max(output[0], output[2]) / 100,
      math.max(output[1], output[3]) / 100,
    ];
  }

  void dispose() => calloc.free(output);
}
