import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:booklet/ui/components/component_state.dart';

enum DrawingTool { pen, line, rectangle, ellipse, circle, text, image }

enum DrawingBrush { pencil, marker, highlighter, spray }

/// Coordinates are stored in a fixed canvas space, independent of screen size.
class DrawingElement {
  DrawingElement({
    required this.tool,
    required List<Offset> points,
    this.color = Colors.black,
    this.width = 4,
    this.text = '',
    this.fontSize = 36,
    this.bold = false,
    this.italic = false,
    this.filled = false,
    this.outlined = false,
    this.fillColor = Colors.white,
    this.brush = DrawingBrush.pencil,
    this.fontFamily = 'sans-serif',
    this.shadow = false,
    this.imageData,
  }) : points = List.unmodifiable(points);
  final DrawingTool tool;
  final List<Offset> points;
  final Color color, fillColor;
  final DrawingBrush brush;
  final String fontFamily;
  final bool shadow;

  /// Embedded PNG bytes, so drawings are independent of source file paths.
  final String? imageData;

  DrawingElement copyWith({
    List<Offset>? points,
    Color? color,
    Color? fillColor,
    double? width,
    String? text,
    double? fontSize,
    bool? bold,
    bool? italic,
    bool? filled,
    bool? outlined,
    bool? shadow,
    String? fontFamily,
    DrawingBrush? brush,
  }) => DrawingElement(
    tool: tool,
    imageData: imageData,
    points: points ?? this.points,
    color: color ?? this.color,
    fillColor: fillColor ?? this.fillColor,
    width: width ?? this.width,
    text: text ?? this.text,
    fontSize: fontSize ?? this.fontSize,
    bold: bold ?? this.bold,
    italic: italic ?? this.italic,
    filled: filled ?? this.filled,
    outlined: outlined ?? this.outlined,
    shadow: shadow ?? this.shadow,
    fontFamily: fontFamily ?? this.fontFamily,
    brush: brush ?? this.brush,
  );

  Rect get bounds {
    if (points.isEmpty) return Rect.zero;
    if (tool == DrawingTool.text) {
      final painter = textPainter(this);
      return points.first & painter.size;
    }
    var rect = Rect.fromPoints(points.first, points.last);
    for (final p in points) {
      rect = rect.expandToInclude(Rect.fromLTWH(p.dx, p.dy, 0, 0));
    }
    return rect;
  }

  bool hitTest(Offset point, double tolerance) {
    if (!bounds.inflate(tolerance + width / 2).contains(point)) return false;
    if (tool == DrawingTool.text || tool == DrawingTool.image) return true;
    if (tool == DrawingTool.rectangle && filled) return true;
    if (tool == DrawingTool.pen || tool == DrawingTool.line) {
      if (points.length == 1) {
        return (point - points.first).distance <= tolerance + width / 2;
      }
      for (var i = 1; i < points.length; i++) {
        final a = points[i - 1], delta = points[i] - a;
        final t = delta.distanceSquared == 0
            ? 0.0
            : (((point - a).dx * delta.dx + (point - a).dy * delta.dy) /
                      delta.distanceSquared)
                  .clamp(0.0, 1.0);
        if ((point - (a + delta * t)).distance <= tolerance + width / 2) {
          return true;
        }
      }
      return false;
    }
    if (tool == DrawingTool.ellipse || tool == DrawingTool.circle) {
      final r = bounds;
      if (r.width == 0 || r.height == 0) return true;
      final x = (point.dx - r.center.dx) / (r.width / 2);
      final y = (point.dy - r.center.dy) / (r.height / 2);
      if (filled) return x * x + y * y <= 1;
      return ((math.sqrt(x * x + y * y) - 1).abs() *
              math.min(r.width, r.height) /
              2) <=
          tolerance + width / 2;
    }
    return !bounds.deflate(tolerance + width / 2).contains(point);
  }

  DrawingElement translated(Offset delta) =>
      copyWith(points: [for (final p in points) p + delta]);
  DrawingElement resized(double scaleX, double scaleY) {
    final origin = bounds.topLeft;
    return copyWith(
      points: [
        for (final p in points)
          origin +
              Offset((p.dx - origin.dx) * scaleX, (p.dy - origin.dy) * scaleY),
      ],
      fontSize: tool == DrawingTool.text
          ? (fontSize * scaleY).clamp(8, 400)
          : fontSize,
    );
  }

  static TextPainter textPainter(DrawingElement e, {bool outline = false}) =>
      TextPainter(
        text: TextSpan(
          text: e.text,
          style: TextStyle(
            fontFamily: e.fontFamily,
            fontFamilyFallback: const ['Arial', 'sans-serif'],
            fontSize: e.fontSize,
            fontWeight: e.bold ? FontWeight.bold : FontWeight.normal,
            fontStyle: e.italic ? FontStyle.italic : FontStyle.normal,
            color: outline ? null : e.fillColor,
            foreground: outline
                ? (Paint()
                    ..color = e.color
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = e.width.clamp(1, 6))
                : null,
            shadows: !outline && e.shadow
                ? const [
                    Shadow(
                      color: Color(0x88000000),
                      offset: Offset(4, 4),
                      blurRadius: 3,
                    ),
                  ]
                : null,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 1200);

  final double width;
  final String text;
  final double fontSize;
  final bool bold, italic, filled, outlined;

  Map<String, dynamic> toJson() => {
    'tool': tool.name,
    'points': [
      for (final p in points) [p.dx, p.dy],
    ],
    'color': color.toARGB32(),
    'fillColor': fillColor.toARGB32(),
    'brush': brush.name,
    'fontFamily': fontFamily,
    'shadow': shadow,
    if (imageData != null) 'imageData': imageData,
    'width': width,
    'text': text,
    'fontSize': fontSize,
    'bold': bold,
    'italic': italic,
    'filled': filled,
    'outlined': outlined,
  };
  factory DrawingElement.fromJson(Map<String, dynamic> json) => DrawingElement(
    tool: DrawingTool.values.byName(json['tool'] as String),
    points: [
      for (final p in json['points'] as List)
        Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
    ],
    color: Color(json['color'] as int),
    fillColor: Color(json['fillColor'] as int? ?? (json['color'] as int)),
    brush: DrawingBrush.values.byName(json['brush'] as String? ?? 'pencil'),
    fontFamily: json['fontFamily'] as String? ?? 'sans-serif',
    shadow: json['shadow'] == true,
    imageData: json['imageData'] as String?,
    width: (json['width'] as num).toDouble(),
    text: json['text'] as String? ?? '',
    fontSize: (json['fontSize'] as num? ?? 36).toDouble(),
    bold: json['bold'] == true,
    italic: json['italic'] == true,
    filled: json['filled'] == true,
    outlined: json['outlined'] == true,
  );
}

class DrawingComponentState extends ComponentState {
  List<DrawingElement> _elements = const [];
  Uint8List? _preview;
  Color backgroundColor = Colors.white;
  Size canvasSize = DrawingPainter.canvasSize;
  List<DrawingElement> get elements => _elements;
  Uint8List? get preview => _preview;
  void save(
    List<DrawingElement> elements,
    Uint8List preview, {
    Color backgroundColor = Colors.white,
    Size canvasSize = DrawingPainter.canvasSize,
  }) {
    this.backgroundColor = backgroundColor;
    this.canvasSize = canvasSize;
    _elements = List.unmodifiable(elements);
    _preview = Uint8List.fromList(preview);
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
    'canvasWidth': canvasSize.width,
    'canvasHeight': canvasSize.height,
    'backgroundColor': backgroundColor.toARGB32(),
    'elements': [for (final e in _elements) e.toJson()],
    if (_preview != null) 'preview': base64Encode(_preview!),
  };
  void restore(Map<String, dynamic> json) {
    backgroundColor = Color(json['backgroundColor'] as int? ?? 0xFFFFFFFF);
    final width = (json['canvasWidth'] as num? ?? 1200).toDouble();
    final height = (json['canvasHeight'] as num? ?? 800).toDouble();
    canvasSize = Size(
      width.isFinite ? width.clamp(64, 4096) : 1200,
      height.isFinite ? height.clamp(64, 4096) : 800,
    );
    _elements = List.unmodifiable([
      for (final e in json['elements'] as List? ?? [])
        DrawingElement.fromJson(Map<String, dynamic>.from(e as Map)),
    ]);
    _preview = json['preview'] is String
        ? base64Decode(json['preview'] as String)
        : null;
    notifyListeners();
  }

  @override
  String? get output => _preview == null
      ? null
      : 'data:image/png;base64,${base64Encode(_preview!)}';
}

class DrawingPainter extends CustomPainter {
  DrawingPainter(
    this.elements, {
    this.backgroundColor = Colors.white,
    this.selectedIndex,
    this.documentSize = canvasSize,
    this.selectedIndices = const {},
    this.selectionRect,
    this.images = const {},
  });
  final Color backgroundColor;
  final Size documentSize;
  final int? selectedIndex;
  final Set<int> selectedIndices;
  final Rect? selectionRect;
  final Map<String, ui.Image> images;
  static const canvasSize = Size(1200, 800);
  final List<DrawingElement> elements;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(
      size.width / documentSize.width,
      size.height / documentSize.height,
    );
    canvas.clipRect(Offset.zero & documentSize);
    canvas.drawColor(backgroundColor, BlendMode.src);
    for (final e in elements) {
      if (e.points.isEmpty) continue;
      final paint = Paint()
        ..color = e.color
        ..strokeWidth = e.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final start = e.points.first, end = e.points.last;
      switch (e.tool) {
        case DrawingTool.pen:
          if (e.brush == DrawingBrush.spray) {
            final random = math.Random(42);
            for (final p in e.points) {
              for (var i = 0; i < 12; i++) {
                final angle = random.nextDouble() * math.pi * 2;
                final radius = math.sqrt(random.nextDouble()) * e.width * 2;
                canvas.drawCircle(
                  p +
                      Offset(
                        math.cos(angle) * radius,
                        math.sin(angle) * radius,
                      ),
                  0.9,
                  Paint()..color = e.color,
                );
              }
            }
          } else {
            if (e.brush == DrawingBrush.highlighter) {
              canvas.saveLayer(
                null,
                Paint()..color = Colors.white.withValues(alpha: .35),
              );
            }
            paint.strokeWidth = e.brush == DrawingBrush.pencil
                ? e.width
                : e.width * 3;
            paint.strokeCap = e.brush == DrawingBrush.highlighter
                ? StrokeCap.square
                : StrokeCap.round;
            if (e.points.length == 1) {
              canvas.drawCircle(
                start,
                paint.strokeWidth / 2,
                Paint()..color = e.color,
              );
            } else {
              final path = Path()..moveTo(start.dx, start.dy);
              for (final p in e.points.skip(1)) {
                path.lineTo(p.dx, p.dy);
              }
              canvas.drawPath(path, paint);
            }
            if (e.brush == DrawingBrush.highlighter) canvas.restore();
          }
        case DrawingTool.line:
          canvas.drawLine(start, end, paint);
        case DrawingTool.rectangle:
        case DrawingTool.ellipse:
        case DrawingTool.circle:
          final rect = Rect.fromPoints(start, end);
          if (e.filled) {
            final fill = Paint()..color = e.fillColor;
            if (e.tool == DrawingTool.rectangle) {
              canvas.drawRect(rect, fill);
            } else {
              canvas.drawOval(rect, fill);
            }
          }
          if (e.width > 0) {
            if (e.tool == DrawingTool.rectangle) {
              canvas.drawRect(rect, paint);
            } else {
              canvas.drawOval(rect, paint);
            }
          }
        case DrawingTool.image:
          final image = images[e.imageData];
          if (image != null) {
            canvas.drawImageRect(
              image,
              Rect.fromLTWH(
                0,
                0,
                image.width.toDouble(),
                image.height.toDouble(),
              ),
              Rect.fromPoints(start, end),
              Paint()..filterQuality = FilterQuality.medium,
            );
          }
        case DrawingTool.text:
          DrawingElement.textPainter(e).paint(canvas, start);
          if (e.outlined) {
            DrawingElement.textPainter(e, outline: true).paint(canvas, start);
          }
      }
    }
    final selected = {...selectedIndices, ?selectedIndex};
    for (final index in selected) {
      if (index < 0 || index >= elements.length) continue;
      final rect = elements[index].bounds.inflate(8);
      final screenScale = documentSize.width / size.width;
      final paint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * screenScale;
      canvas.drawRect(rect, paint);
      if (selected.length == 1) {
        canvas.drawRect(
          Rect.fromCenter(
            center: rect.bottomRight,
            width: 12 * screenScale,
            height: 12 * screenScale,
          ),
          Paint()..color = Colors.blue,
        );
      }
    }
    if (selectionRect != null) {
      canvas.drawRect(
        selectionRect!,
        Paint()..color = Colors.blue.withValues(alpha: .12),
      );
      canvas.drawRect(
        selectionRect!,
        Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) => true;

  static Future<Uint8List> render(
    List<DrawingElement> elements, {
    Color backgroundColor = Colors.white,
    Size canvasSize = DrawingPainter.canvasSize,
  }) async {
    final decoded = <String, ui.Image>{};
    try {
      for (final e in elements) {
        final data = e.imageData;
        if (e.tool == DrawingTool.image &&
            data != null &&
            !decoded.containsKey(data)) {
          final codec = await ui.instantiateImageCodec(base64Decode(data));
          try {
            decoded[data] = (await codec.getNextFrame()).image;
          } finally {
            codec.dispose();
          }
        }
      }
      return await _render(
        elements,
        backgroundColor: backgroundColor,
        canvasSize: canvasSize,
        images: decoded,
      );
    } finally {
      for (final image in decoded.values) {
        image.dispose();
      }
    }
  }

  static Future<Uint8List> _render(
    List<DrawingElement> elements, {
    required Color backgroundColor,
    required Size canvasSize,
    required Map<String, ui.Image> images,
  }) async {
    final recorder = ui.PictureRecorder();
    DrawingPainter(
      elements,
      backgroundColor: backgroundColor,
      documentSize: canvasSize,
      images: images,
    ).paint(Canvas(recorder), canvasSize);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      canvasSize.width.toInt(),
      canvasSize.height.toInt(),
    );
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Could not export drawing');
      return bytes.buffer.asUint8List();
    } finally {
      image.dispose();
      picture.dispose();
    }
  }
}
