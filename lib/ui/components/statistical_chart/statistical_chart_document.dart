import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:booklet/ui/components/component_state.dart';

enum ChartType {
  bar,
  column,
  horizontalBar,
  line,
  pie,
  doughnut,
  area,
  scatter,
  treemap,
  step,
  groupedBar,
  stackedBar,
  multiLine,
  stacked100,
  bubble;

  String get label => switch (this) {
    bar => 'Bar',
    column => 'Column',
    horizontalBar => 'Horizontal Bar',
    line => 'Line',
    pie => 'Pie',
    doughnut => 'Donut',
    area => 'Area',
    scatter => 'Scatter Plot',
    treemap => 'Treemap',
    step => 'Step Chart',
    groupedBar => 'Grouped Columns',
    stackedBar => 'Stacked Columns',
    multiLine => 'Line (multiple series)',
    stacked100 => '100% Stacked Bar',
    bubble => 'Bubble Chart',
  };
  bool get composition => [pie, doughnut, treemap, stacked100].contains(this);
}

/// User-facing chart families are independent of the saved dataset format.
enum ChartFamily {
  barColumn('Bar & Column', 'Compare values across items.', [
    ChartType.column,
    ChartType.horizontalBar,
    ChartType.groupedBar,
    ChartType.stackedBar,
  ]),
  lineArea('Line & Area', 'Show changes, trends, or ordered values.', [
    ChartType.line,
    ChartType.area,
    ChartType.step,
  ]),
  partsWhole(
    'Parts of a Whole',
    'Show how individual amounts make up a total.',
    [
      ChartType.pie,
      ChartType.doughnut,
      ChartType.stacked100,
      ChartType.treemap,
    ],
  ),
  scatterBubble(
    'Scatter & Bubble',
    'Explore relationships between numeric X and Y values.',
    [ChartType.scatter, ChartType.bubble],
  );

  const ChartFamily(this.label, this.description, this.types);
  final String label;
  final String description;
  final List<ChartType> types;
  static ChartFamily forType(ChartType type) => switch (type) {
    ChartType.bar => barColumn,
    ChartType.multiLine => lineArea,
    _ => values.firstWhere((f) => f.types.contains(type)),
  };
}

// Kept as storage formats so existing graph documents continue to load.
enum ChartDataFormat {
  categorical('Text labels', 'Label', 'labels'),
  timeSeries('Dates', 'Date (YYYY-MM-DD)', 'dates'),
  grouped('Text labels', 'Label', 'labels'),
  composition('Text labels', 'Label', 'labels'),
  xy('Numbers (X values)', 'X', 'xValues');

  const ChartDataFormat(this.label, this.columnLabel, this.dataKey);
  final String label;
  final String columnLabel;
  final String dataKey;
  bool get supportsSeries => true;
  List<ChartType> get types => ChartType.values
      .where(
        (t) => this == xy || (t != ChartType.scatter && t != ChartType.bubble),
      )
      .toList();
  bool validLabel(String value) => switch (this) {
    xy => double.tryParse(value)?.isFinite == true,
    timeSeries => validDate(value),
    _ => true,
  };
  static bool validDate(String value) {
    final date = DateTime.tryParse(value);
    return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
        date != null &&
        date.toIso8601String().startsWith(value);
  }
}

class ChartSeries {
  ChartSeries(this.name, this.values);
  String name;
  List<double> values;
  Map<String, dynamic> toJson() => {'name': name, 'values': List.of(values)};
}

class StatisticalChartState extends ComponentState {
  ChartDataFormat category = ChartDataFormat.categorical;
  ChartType type = ChartType.column;
  String title = '';
  List<String> labels = ['A', 'B', 'C'];
  List<double> values = [3, 7, 5];
  String metricName = 'Value';
  List<ChartSeries> series = [];
  List<double> bubbleSizes = [];
  List<ChartSeries> get metrics => [ChartSeries(metricName, values), ...series];
  Map<String, dynamic> toJson() => {
    'datasetFormat': category.name,
    'graphType': type.name,
    'title': title,
    category.dataKey: category == ChartDataFormat.xy
        ? labels.map(double.parse).toList()
        : List.of(labels),
    'values': List.of(values),
    if (category.supportsSeries) 'metricName': metricName,
    if (category.supportsSeries)
      'series': series.map((s) => s.toJson()).toList(),
    if (category == ChartDataFormat.xy && bubbleSizes.isNotEmpty)
      'sizes': List.of(bubbleSizes),
  };
  void restore(Map<String, dynamic> json) {
    category = ChartDataFormat.values.firstWhere(
      (c) => c.name == json['datasetFormat'],
      orElse: () => ChartDataFormat.categorical,
    );
    type = category.types.firstWhere(
      (t) => t.name == json['graphType'],
      orElse: () =>
          category == ChartDataFormat.categorical &&
              ['line', 'area'].contains(json['graphType'])
          ? ChartType.values.byName(json['graphType'] as String)
          : category == ChartDataFormat.timeSeries && json['graphType'] == 'bar'
          ? ChartType.column
          : category.types.first,
    );
    title = json['title'] is String ? json['title'] as String : '';
    final rawLabels = json[category.dataKey];
    final rawValues = json['values'];
    if (rawLabels is List &&
        rawValues is List &&
        rawLabels.length == rawValues.length &&
        rawLabels.every((v) => category.validLabel(v.toString())) &&
        rawValues.every((v) => v is num && v.isFinite)) {
      labels = rawLabels.map((v) => v.toString()).toList();
      values = rawValues.map((v) => (v as num).toDouble()).toList();
    }
    if (labels.any((v) => !category.validLabel(v))) {
      labels = [];
      values = [];
    }
    metricName = json['metricName'] is String
        ? json['metricName'] as String
        : 'Value';
    series = [];
    if (category.supportsSeries && json['series'] is List) {
      for (final item in json['series'] as List) {
        if (item is Map &&
            item['name'] is String &&
            validNumbers(item['values'], labels.length)) {
          series.add(
            ChartSeries(
              item['name'] as String,
              (item['values'] as List)
                  .map((v) => (v as num).toDouble())
                  .toList(),
            ),
          );
        }
      }
    }
    bubbleSizes = validNumbers(json['sizes'], labels.length)
        ? (json['sizes'] as List).map((v) => (v as num).toDouble()).toList()
        : [];
    notifyListeners();
  }

  static bool validNumbers(Object? raw, int length) =>
      raw is List &&
      raw.length == length &&
      raw.every((v) => v is num && v.isFinite);

  static void validateJson(Map<String, dynamic> json) {
    final category = ChartDataFormat.values
        .where((c) => c.name == (json['datasetFormat'] ?? 'categorical'))
        .firstOrNull;
    if (category == null) throw const FormatException('Unknown datasetFormat.');
    if (!category.types.any((t) => t.name == json['graphType']) &&
        !(category == ChartDataFormat.categorical &&
            ['line', 'area'].contains(json['graphType']))) {
      throw FormatException(
        'Choose a compatible graphType: ${category.types.map((t) => t.name).join(', ')}.',
      );
    }
    if (json['title'] is! String) {
      throw const FormatException('Title must be a string.');
    }
    final labels = json[category.dataKey];
    if (labels is! List ||
        !labels.every(
          (v) =>
              (category == ChartDataFormat.xy ? v is num : v is String) &&
              category.validLabel(v.toString()),
        ) ||
        !validNumbers(json['values'], labels.length)) {
      throw FormatException(
        'Expected ${category.dataKey} and finite numeric values with matching lengths.',
      );
    }
    final series = json['series'] ?? [];
    if (category.supportsSeries) {
      if (series is! List ||
          !series.every(
            (v) =>
                v is Map &&
                v['name'] is String &&
                (v['name'] as String).trim().isNotEmpty &&
                validNumbers(v['values'], labels.length),
          )) {
        throw const FormatException(
          'Every value column needs a name and one finite number per row.',
        );
      }
      if (json.containsKey('metricName') &&
          (json['metricName'] is! String ||
              (json['metricName'] as String).trim().isEmpty)) {
        throw const FormatException('The first metric needs a name.');
      }
    } else if (series is! List || series.isNotEmpty) {
      throw const FormatException('This category supports one metric.');
    }
    final type = ChartType.values.byName(json['graphType'] as String);
    final extraMetrics = series.length;
    if ([
          ChartType.groupedBar,
          ChartType.stackedBar,
          ChartType.multiLine,
        ].contains(type) &&
        extraMetrics == 0) {
      throw const FormatException(
        'Add another value column in Data set to compare or stack multiple series.',
      );
    }
    if ((type.composition ||
            type == ChartType.scatter ||
            type == ChartType.bubble) &&
        extraMetrics > 0) {
      throw const FormatException(
        'This chart uses one value column. Remove extra value columns or choose a Bar, Column, Line, or Area chart.',
      );
    }

    if (type.composition) {
      final values = (json['values'] as List).cast<num>();
      if (values.any((v) => v < 0) ||
          (values.isNotEmpty && values.every((v) => v == 0))) {
        throw const FormatException(
          'Composition values must be non-negative with a positive total.',
        );
      }
    }
    if (json.containsKey('sizes') &&
        (!validNumbers(json['sizes'], labels.length) ||
            (json['sizes'] as List).any((v) => (v as num) < 0))) {
      throw const FormatException(
        'Bubble sizes must be non-negative numbers, one per row.',
      );
    }
  }

  @override
  Object get output => toJson();
}

/// Scale areas proportionally, independent of the measurement unit.
/// Missing sizes use equal bubbles; zero values have zero area.
List<double> bubbleMarkerRadii(
  List<double> sizes,
  int count, {
  double maxRadius = 24,
}) {
  final values = sizes.length == count
      ? sizes.map((v) => v.isFinite ? math.max(0.0, v) : 0.0).toList()
      : List.filled(count, 1.0);
  final largest = values.fold<double>(0, math.max);
  return values
      .map((v) => largest == 0 ? 0.0 : math.sqrt(v / largest) * maxRadius)
      .toList();
}

class StatisticalChartPreview extends StatelessWidget {
  const StatisticalChartPreview({super.key, required this.state});
  final StatisticalChartState state;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (state.title.isNotEmpty)
        Text(state.title, style: Theme.of(context).textTheme.titleMedium),
      SizedBox(
        height: 240,
        width: double.infinity,
        child: CustomPaint(
          painter: _StatisticalChartPainter(
            state,
            Theme.of(context).colorScheme,
          ),
        ),
      ),
      if (state.category.supportsSeries)
        Wrap(
          spacing: 16,
          children: List.generate(
            state.metrics.length,
            (i) => Text(
              state.metrics[i].name,
              style: TextStyle(
                color: _colors[i % _colors.length],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      Wrap(
        spacing: 16,
        children: List.generate(
          state.values.length,
          (i) => Text(
            '${state.labels[i]}: ${state.metrics.map((m) => state.category.supportsSeries ? '${m.name} ${m.values[i]}' : '${m.values[i]}').join(', ')}',
            style: TextStyle(color: _colors[i % _colors.length]),
          ),
        ),
      ),
      if (state.type == ChartType.bubble &&
          state.values.isNotEmpty &&
          (state.bubbleSizes.isEmpty ||
              state.bubbleSizes.every((v) => v == state.bubbleSizes.first)))
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'All bubbles have the same Size. Edit the Size column in Data set to compare another measurement.',
          ),
        ),
      if ((state.type == ChartType.pie || state.type == ChartType.doughnut) &&
          state.values.any((v) => v < 0))
        const Text('Pie charts show positive values only.'),
    ],
  );
}

const _colors = [
  Colors.blue,
  Colors.orange,
  Colors.teal,
  Colors.purple,
  Colors.red,
];

class _StatisticalChartPainter extends CustomPainter {
  _StatisticalChartPainter(this.state, this.colors);
  final StatisticalChartState state;
  final ColorScheme colors;
  @override
  void paint(Canvas canvas, Size size) {
    if (state.values.isEmpty) return;
    final plot = Rect.fromLTWH(
      44,
      16,
      math.max(1, size.width - 60),
      math.max(1, size.height - 42),
    );
    final paint = Paint();
    final values = state.values;
    final type = state.type;
    void text(String label, Offset at, {double width = 40}) {
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(color: colors.onSurface, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width);
      painter.paint(canvas, at);
    }

    if (type.composition) {
      final total = values.fold<double>(0, (a, b) => a + math.max(0, b));
      if (total <= 0) return;
      var start = 0.0;
      final circle = Rect.fromCircle(
        center: size.center(Offset.zero),
        radius: math.min(size.width, size.height) * .42,
      );
      var remaining = plot;
      for (var i = 0; i < values.length; i++) {
        final fraction = math.max(0, values[i]) / total;
        paint.color = _colors[i % _colors.length];
        if (type == ChartType.pie || type == ChartType.doughnut) {
          canvas.drawArc(
            circle,
            -math.pi / 2 + start * math.pi * 2,
            fraction * math.pi * 2,
            true,
            paint,
          );
        } else if (type == ChartType.stacked100) {
          canvas.drawRect(
            Rect.fromLTWH(
              plot.left + start * plot.width,
              plot.center.dy - 35,
              fraction * plot.width,
              70,
            ),
            paint,
          );
        } else {
          final remainder = 1 - start;
          if (fraction > 0 && remainder > 0) {
            final ratio = (fraction / remainder).clamp(0.0, 1.0);
            final horizontal = remaining.width >= remaining.height;
            final rect = horizontal
                ? Rect.fromLTWH(
                    remaining.left,
                    remaining.top,
                    remaining.width * ratio,
                    remaining.height,
                  )
                : Rect.fromLTWH(
                    remaining.left,
                    remaining.top,
                    remaining.width,
                    remaining.height * ratio,
                  );
            canvas.drawRect(rect.deflate(1), paint);
            if (rect.width > 35 && rect.height > 20) {
              text(
                state.labels[i],
                rect.topLeft + const Offset(4, 4),
                width: math.max(1, rect.width - 8),
              );
            }
            remaining = horizontal
                ? Rect.fromLTRB(
                    rect.right,
                    remaining.top,
                    remaining.right,
                    remaining.bottom,
                  )
                : Rect.fromLTRB(
                    remaining.left,
                    rect.bottom,
                    remaining.right,
                    remaining.bottom,
                  );
          }
        }
        start += fraction;
      }
      if (type == ChartType.doughnut) {
        canvas.drawCircle(
          size.center(Offset.zero),
          circle.width * .28,
          paint..color = colors.surface,
        );
      }
      if (type == ChartType.stacked100) {
        text('0%', Offset(plot.left, plot.center.dy + 40));
        text('100%', Offset(plot.right - 30, plot.center.dy + 40));
      }
      return;
    }
    final metrics = state.category.supportsSeries
        ? state.metrics
        : [ChartSeries(state.metricName, values)];
    var low = 0.0, high = 0.0;
    for (var i = 0; i < values.length; i++) {
      if (type == ChartType.stackedBar) {
        var positive = 0.0, negative = 0.0;
        for (final m in metrics) {
          if (m.values[i] >= 0) {
            positive += m.values[i];
          } else {
            negative += m.values[i];
          }
        }
        low = math.min(low, negative);
        high = math.max(high, positive);
      } else {
        for (final m in metrics) {
          low = math.min(low, m.values[i]);
          high = math.max(high, m.values[i]);
        }
      }
    }
    final range = high == low ? 1.0 : high - low;
    double y(double v) => plot.bottom - (v - low) / range * plot.height;
    final horizontal = type == ChartType.horizontalBar;
    if (horizontal) {
      double x(double v) => plot.left + (v - low) / range * plot.width;
      final step = plot.height / values.length;
      canvas.drawLine(
        Offset(x(0), plot.top),
        Offset(x(0), plot.bottom),
        paint..color = colors.outline,
      );
      for (var i = 0; i < values.length; i++) {
        canvas.drawRect(
          Rect.fromLTRB(
            math.min(x(0), x(values[i])),
            plot.top + step * (i + .2),
            math.max(x(0), x(values[i])),
            plot.top + step * (i + .8),
          ),
          paint..color = _colors[i % _colors.length],
        );
        text(state.labels[i], Offset(0, plot.top + step * (i + .3)));
      }
      text(low.toStringAsPrecision(3), Offset(plot.left, plot.bottom + 4));
      text(
        high.toStringAsPrecision(3),
        Offset(plot.right - 35, plot.bottom + 4),
      );
      return;
    }
    canvas.drawLine(
      Offset(plot.left, y(0)),
      Offset(plot.right, y(0)),
      paint
        ..color = colors.outline
        ..strokeWidth = 1,
    );
    text(low.toStringAsPrecision(3), Offset(0, y(low) - 8));
    text(high.toStringAsPrecision(3), Offset(0, y(high)));
    final step = plot.width / values.length;
    final chronological =
        state.category == ChartDataFormat.timeSeries ||
        (state.category == ChartDataFormat.grouped &&
            state.labels.every(ChartDataFormat.validDate));
    final xs = state.category == ChartDataFormat.xy
        ? state.labels.map(double.parse).toList()
        : chronological
        ? state.labels
              .map((v) => DateTime.parse(v).millisecondsSinceEpoch.toDouble())
              .toList()
        : null;
    final xLow = xs == null ? 0.0 : xs.reduce(math.min);
    final xHigh = xs == null ? 0.0 : xs.reduce(math.max);
    double x(int i) => xs == null || xHigh == xLow
        ? plot.left + step * (i + .5)
        : plot.left +
              step / 2 +
              (xs[i] - xLow) / (xHigh - xLow) * (plot.width - step);
    final order = List.generate(values.length, (i) => i);
    if (xs != null) order.sort((a, b) => xs[a].compareTo(xs[b]));
    final bubbleRadii = bubbleMarkerRadii(state.bubbleSizes, values.length);
    final positive = List.filled(values.length, 0.0),
        negative = List.filled(values.length, 0.0);
    for (var m = 0; m < metrics.length; m++) {
      final metric = metrics[m];
      final color = metrics.length == 1
          ? colors.primary
          : _colors[m % _colors.length];
      final path = Path();
      Offset? previous;
      for (final i in order) {
        final value = metric.values[i];
        final point = Offset(x(i), y(value));
        paint
          ..color = color
          ..strokeWidth = 2;
        if ([
          ChartType.bar,
          ChartType.column,
          ChartType.groupedBar,
          ChartType.stackedBar,
        ].contains(type)) {
          var base = 0.0, top = value;
          if (type == ChartType.stackedBar) {
            base = value >= 0 ? positive[i] : negative[i];
            top = base + value;
            if (value >= 0) {
              positive[i] = top;
            } else {
              negative[i] = top;
            }
          }
          final width =
              step * .7 / (type == ChartType.stackedBar ? 1 : metrics.length);
          final left =
              point.dx -
              step * .35 +
              (type == ChartType.stackedBar ? 0 : m * width);
          canvas.drawRect(
            Rect.fromLTRB(
              left,
              math.min(y(base), y(top)),
              left + width,
              math.max(y(base), y(top)),
            ),
            paint,
          );
        } else {
          if (previous == null) {
            path.moveTo(point.dx, point.dy);
          } else if (type == ChartType.step) {
            path.lineTo(point.dx, previous.dy);
            path.lineTo(point.dx, point.dy);
          } else {
            path.lineTo(point.dx, point.dy);
          }
          if (type == ChartType.scatter || type == ChartType.bubble) {
            final radius = type == ChartType.bubble ? bubbleRadii[i] : 4.0;
            canvas.drawCircle(
              point,
              radius,
              paint..color = color.withValues(alpha: .65),
            );
          }
          previous = point;
        }
      }
      if (![
        ChartType.scatter,
        ChartType.bubble,
        ChartType.bar,
        ChartType.column,
        ChartType.groupedBar,
        ChartType.stackedBar,
      ].contains(type)) {
        canvas.drawPath(
          path,
          paint
            ..color = color
            ..style = PaintingStyle.stroke,
        );
        paint.style = PaintingStyle.fill;
        if (type == ChartType.area && order.isNotEmpty) {
          path
            ..lineTo(x(order.last), y(0))
            ..lineTo(x(order.first), y(0))
            ..close();
          canvas.drawPath(path, paint..color = color.withValues(alpha: .2));
        }
      }
    }
    text(
      state.labels[order.first],
      Offset(plot.left, plot.bottom + 4),
      width: 90,
    );
    if (order.length > 1) {
      text(
        state.labels[order.last],
        Offset(plot.right - 85, plot.bottom + 4),
        width: 90,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StatisticalChartPainter oldDelegate) => true;
}
