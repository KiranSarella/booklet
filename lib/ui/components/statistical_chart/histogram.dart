import 'dart:math' as math;

class HistogramBin {
  const HistogramBin(this.lower, this.upper, this.count, this.includesUpper);
  final double lower, upper;
  final int count;
  final bool includesUpper;
}

/// Equal-width bins. Internal boundaries belong to the bin on their right;
/// the final bin includes the maximum. Automatic counts use Sturges' rule.
List<HistogramBin> buildHistogram(List<double> values, {int? binCount}) {
  if (binCount != null && (binCount < 1 || binCount > 100)) {
    throw const FormatException('Choose between 1 and 100 bins, or Auto.');
  }
  if (values.any((v) => !v.isFinite)) {
    throw const FormatException('Observations must be finite numbers.');
  }
  if (values.isEmpty) return [];
  var low = values.reduce(math.min), high = values.reduce(math.max);
  final constant = low == high;
  if (constant) {
    final padding = math.max(.5, low.abs() * .01);
    final a = low - padding, b = high + padding;
    if (a.isFinite) low = a;
    if (b.isFinite) high = b;
  }
  final range = high - low;
  if (!range.isFinite || range <= 0) {
    throw const FormatException(
      'The observation range is too large to plot. Use smaller units.',
    );
  }
  var count =
      binCount ??
      (constant ? 1 : (math.log(values.length) / math.ln2).ceil() + 1).clamp(
        1,
        100,
      );
  List<double> edges() => [
    for (var i = 0; i <= count; i++)
      i == count ? high : low + range * (i / count),
  ];
  var boundaries = edges();
  // Adjacent floating-point values may not leave room for the requested bins.
  while (count > 1 &&
      List.generate(
        count,
        (i) => boundaries[i + 1] <= boundaries[i],
      ).any((v) => v)) {
    count = (count / 2).ceil();
    boundaries = edges();
  }
  final frequencies = List.filled(count, 0);
  for (final value in values) {
    var position = (value - low) / range * count;
    final nearest = position.roundToDouble();
    if ((position - nearest).abs() < 1e-12) position = nearest;
    final index = position.floor().clamp(0, count - 1);
    frequencies[index]++;
  }
  return List.generate(
    count,
    (i) => HistogramBin(
      boundaries[i],
      boundaries[i + 1],
      frequencies[i],
      i == count - 1,
    ),
  );
}
