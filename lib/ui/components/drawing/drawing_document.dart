import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:booklet/ui/components/component_state.dart';

enum DrawingTool { pen, line, rectangle, ellipse, text }

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
  }) : points = List.unmodifiable(points);
  final DrawingTool tool;
  final List<Offset> points;
  final Color color;
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
  List<DrawingElement> get elements => _elements;
  Uint8List? get preview => _preview;
  void save(List<DrawingElement> elements, Uint8List preview) {
    _elements = List.unmodifiable(elements);
    _preview = Uint8List.fromList(preview);
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
    'elements': [for (final e in _elements) e.toJson()],
    if (_preview != null) 'preview': base64Encode(_preview!),
  };
  void restore(Map<String, dynamic> json) {
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
  DrawingPainter(this.elements);
  static const canvasSize = Size(1200, 800);
  final List<DrawingElement> elements;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(
      size.width / canvasSize.width,
      size.height / canvasSize.height,
    );
    canvas.clipRect(Offset.zero & canvasSize);
    canvas.drawColor(Colors.white, BlendMode.src);
    for (final e in elements) {
      if (e.points.isEmpty) continue;
      final paint = Paint()
        ..color = e.color
        ..strokeWidth = e.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = e.filled ? PaintingStyle.fill : PaintingStyle.stroke;
      final start = e.points.first;
      final end = e.points.last;
      switch (e.tool) {
        case DrawingTool.pen:
          if (e.points.length == 1) {
            canvas.drawCircle(start, e.width / 2, Paint()..color = e.color);
          } else {
            final path = Path()..moveTo(start.dx, start.dy);
            for (final p in e.points.skip(1)) {
              path.lineTo(p.dx, p.dy);
            }
            canvas.drawPath(path, paint..style = PaintingStyle.stroke);
          }
        case DrawingTool.line:
          canvas.drawLine(start, end, paint);
        case DrawingTool.rectangle:
          canvas.drawRect(Rect.fromPoints(start, end), paint);
        case DrawingTool.ellipse:
          canvas.drawOval(Rect.fromPoints(start, end), paint);
        case DrawingTool.text:
          final style = TextStyle(
            fontSize: e.fontSize,
            fontWeight: e.bold ? FontWeight.bold : FontWeight.normal,
            fontStyle: e.italic ? FontStyle.italic : FontStyle.normal,
            color: e.outlined ? null : e.color,
            foreground: e.outlined
                ? (Paint()
                    ..color = e.color
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 1.5)
                : null,
          );
          final text =
              TextPainter(
                text: TextSpan(text: e.text, style: style),
                textDirection: TextDirection.ltr,
              )..layout(
                maxWidth: (canvasSize.width - start.dx).clamp(
                  1,
                  canvasSize.width,
                ),
              );
          text.paint(canvas, start);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) => true;

  static Future<Uint8List> render(List<DrawingElement> elements) async {
    final recorder = ui.PictureRecorder();
    DrawingPainter(elements).paint(Canvas(recorder), canvasSize);
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
