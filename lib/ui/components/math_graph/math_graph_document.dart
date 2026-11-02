import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:booklet/ui/components/component_state.dart';

import 'math_expression.dart';

enum MathGraphTemplate {
  linear('Linear', '2*x + 1'),
  polynomial('Polynomial', 'x^2'),
  exponential('Exponential', 'exp(x)'),
  logarithmic('Logarithmic', 'ln(x)'),
  trigonometric('Trigonometric', 'sin(x)'),
  custom('Custom', 'x');

  const MathGraphTemplate(this.label, this.expression);
  final String label, expression;
}

class MathGraphEquation {
  MathGraphEquation(this.expression, {this.visible = true})
    : compiled = MathExpression.parse(expression);
  final String expression;
  final bool visible;
  final MathExpression compiled;
  Map<String, dynamic> toJson() => {
    'expression': expression,
    'visible': visible,
  };
}

class MathGraphDocument {
  MathGraphDocument._(
    this.title,
    this.xMin,
    this.xMax,
    this.yMin,
    this.yMax,
    this.degrees,
    List<MathGraphEquation> equations,
  ) : equations = List.unmodifiable(equations);
  final String title;
  final double xMin, xMax, yMin, yMax;
  final bool degrees;
  final List<MathGraphEquation> equations;
  factory MathGraphDocument.fromJson(Map<String, dynamic> json) {
    final title = json['title'] ?? '';
    if (title is! String) throw const FormatException('Title must be text.');
    double number(String key, double fallback) {
      final value = json[key] ?? fallback;
      if (value is! num || !value.isFinite) {
        throw FormatException('$key must be a finite number.');
      }
      return value.toDouble();
    }

    final xMin = number('xMin', -10),
        xMax = number('xMax', 10),
        yMin = number('yMin', -10),
        yMax = number('yMax', 10);
    if (xMin >= xMax ||
        yMin >= yMax ||
        !(xMax - xMin).isFinite ||
        !(yMax - yMin).isFinite) {
      throw const FormatException(
        'Each axis minimum must be less than its maximum, with a finite range.',
      );
    }
    final unit = json['angleUnit'] ?? 'radians';
    if (unit != 'radians' && unit != 'degrees') {
      throw const FormatException('Choose radians or degrees for angleUnit.');
    }
    final raw = json['equations'];
    if (raw is! List || raw.isEmpty || raw.length > 16) {
      throw const FormatException('Include between 1 and 16 equations.');
    }
    final equations = <MathGraphEquation>[];
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      if (item is! Map ||
          item['expression'] is! String ||
          (item.containsKey('visible') && item['visible'] is! bool)) {
        throw FormatException(
          'Equation ${i + 1} needs expression text and an optional visible boolean.',
        );
      }
      try {
        equations.add(
          MathGraphEquation(
            item['expression'] as String,
            visible: item['visible'] != false,
          ),
        );
      } on FormatException catch (e) {
        throw FormatException('Equation ${i + 1}: ${e.message}');
      }
    }
    return MathGraphDocument._(
      title,
      xMin,
      xMax,
      yMin,
      yMax,
      unit == 'degrees',
      equations,
    );
  }
  Map<String, dynamic> toJson() => {
    'title': title,
    'xMin': xMin,
    'xMax': xMax,
    'yMin': yMin,
    'yMax': yMax,
    'angleUnit': degrees ? 'degrees' : 'radians',
    'equations': equations.map((e) => e.toJson()).toList(),
  };
}

class MathGraphState extends ComponentState {
  MathGraphDocument _document = MathGraphDocument.fromJson({
    'equations': [
      {'expression': 'x^2'},
    ],
  });
  MathGraphDocument get document => _document;
  Map<String, dynamic> toJson() => _document.toJson();
  void restore(Map<String, dynamic> json) {
    final next = MathGraphDocument.fromJson(json);
    _document = next;
    notifyListeners();
  }

  @override
  Object get output => toJson();
}

/// Samples only visible, defined intervals; never bridges a domain gap or an
/// off-screen asymptote. Midpoints catch gaps between adjacent sample locations.
List<List<Offset>> sampleMathGraph(
  MathGraphEquation equation,
  MathGraphDocument document, {
  int samples = 800,
}) {
  if (samples < 2 || samples > 10000) {
    throw RangeError.range(samples, 2, 10000, 'samples');
  }
  if (!equation.visible) return [];
  final segments = <List<Offset>>[];
  var segment = <Offset>[];
  double? visible(double x) {
    final y = equation.compiled.evaluate(x, degrees: document.degrees);
    return y != null && y >= document.yMin && y <= document.yMax ? y : null;
  }

  Offset? previous;
  for (var i = 0; i <= samples; i++) {
    final x = document.xMin + (document.xMax - document.xMin) * (i / samples);
    final y = visible(x);
    if (y == null) {
      previous = null;
      segment = [];
      continue;
    }
    final point = Offset(x, y);
    if (previous != null &&
        (visible(previous.dx + (x - previous.dx) / 2) == null ||
            (previous.dy - y).abs() > (document.yMax - document.yMin) * .5)) {
      segment = [];
    }
    if (segment.isEmpty) {
      segment = [point];
      segments.add(segment);
    } else {
      segment.add(point);
    }
    previous = point;
  }
  return segments;
}

const mathGraphColors = [
  Colors.blue,
  Colors.deepOrange,
  Colors.teal,
  Colors.purple,
  Colors.red,
  Colors.indigo,
];

class MathGraphPreview extends StatelessWidget {
  const MathGraphPreview({super.key, required this.state});
  final MathGraphState state;
  @override
  Widget build(BuildContext context) {
    final document = state.document;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (document.title.isNotEmpty)
          Text(document.title, style: Theme.of(context).textTheme.titleMedium),
        SizedBox(
          height: 320,
          width: double.infinity,
          child: CustomPaint(
            painter: _MathGraphPainter(document, Theme.of(context).colorScheme),
          ),
        ),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: List.generate(
            document.equations.length,
            (i) => Text(
              'y = ${document.equations[i].expression.replaceFirst(RegExp(r'^\s*y\s*=\s*', caseSensitive: false), '')}',
              style: TextStyle(
                color: document.equations[i].visible
                    ? mathGraphColors[i % mathGraphColors.length]
                    : Theme.of(context).disabledColor,
                decoration: document.equations[i].visible
                    ? null
                    : TextDecoration.lineThrough,
              ),
            ),
          ),
        ),
        Text(
          document.degrees ? 'Angles in degrees' : 'Angles in radians',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _MathGraphPainter extends CustomPainter {
  _MathGraphPainter(this.document, this.colors);
  final MathGraphDocument document;
  final ColorScheme colors;
  List<double> ticks(double min, double max) {
    final rough = (max - min) / 6;
    if (rough <= 0 || !rough.isFinite) return [];
    final scale = math
        .pow(10, (math.log(rough) / math.ln10).floor())
        .toDouble();
    if (scale == 0 || !scale.isFinite) return [];
    final fraction = rough / scale;
    final step =
        (fraction <= 1
            ? 1
            : fraction <= 2
            ? 2
            : fraction <= 5
            ? 5
            : 10) *
        scale;
    final first = (min / step).ceilToDouble() * step;
    return [
      for (var i = 0; i < 20 && first + i * step <= max; i++) first + i * step,
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTWH(
      52,
      16,
      math.max(1, size.width - 68),
      math.max(1, size.height - 50),
    );
    double x(double value) =>
        plot.left +
        (value - document.xMin) / (document.xMax - document.xMin) * plot.width;
    double y(double value) =>
        plot.bottom -
        (value - document.yMin) / (document.yMax - document.yMin) * plot.height;
    void label(String value, Offset at, {double width = 48}) {
      final text = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width);
      text.paint(canvas, at);
      text.dispose();
    }

    final grid = Paint()
      ..color = colors.outlineVariant.withValues(alpha: .5)
      ..strokeWidth = .6;
    for (final tick in ticks(document.xMin, document.xMax)) {
      canvas.drawLine(
        Offset(x(tick), plot.top),
        Offset(x(tick), plot.bottom),
        grid,
      );
      label(
        tick.abs() < 1e-12 ? '0' : tick.toStringAsPrecision(3),
        Offset(x(tick) - 15, plot.bottom + 6),
      );
    }
    for (final tick in ticks(document.yMin, document.yMax)) {
      canvas.drawLine(
        Offset(plot.left, y(tick)),
        Offset(plot.right, y(tick)),
        grid,
      );
      label(
        tick.abs() < 1e-12 ? '0' : tick.toStringAsPrecision(3),
        Offset(0, y(tick) - 6),
      );
    }
    canvas.drawRect(
      plot,
      Paint()
        ..color = colors.outlineVariant
        ..style = PaintingStyle.stroke,
    );
    final axes = Paint()
      ..color = colors.onSurfaceVariant
      ..strokeWidth = 1;
    if (document.xMin <= 0 && document.xMax >= 0) {
      canvas.drawLine(Offset(x(0), plot.top), Offset(x(0), plot.bottom), axes);
    }
    if (document.yMin <= 0 && document.yMax >= 0) {
      canvas.drawLine(Offset(plot.left, y(0)), Offset(plot.right, y(0)), axes);
    }
    label('x', Offset(plot.right - 6, plot.bottom + 20));
    label('y', Offset(plot.left - 12, 0));
    canvas.save();
    canvas.clipRect(plot);
    for (var i = 0; i < document.equations.length; i++) {
      final segments = sampleMathGraph(
        document.equations[i],
        document,
        samples: (plot.width * 2).ceil().clamp(200, 1600),
      );
      final paint = Paint()
        ..color = mathGraphColors[i % mathGraphColors.length]
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      for (final segment in segments) {
        final path = Path()..moveTo(x(segment.first.dx), y(segment.first.dy));
        for (final point in segment.skip(1)) {
          path.lineTo(x(point.dx), y(point.dy));
        }
        canvas.drawPath(path, paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MathGraphPainter oldDelegate) =>
      document != oldDelegate.document || colors != oldDelegate.colors;
}
