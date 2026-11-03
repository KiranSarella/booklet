/// Quartiles use linear interpolation at (n - 1) × p (inclusive percentiles).
/// Whiskers end at observed values within the 1.5 × IQR fences.
class BoxPlotSummary {
  const BoxPlotSummary(
    this.q1,
    this.median,
    this.q3,
    this.lowerWhisker,
    this.upperWhisker,
    this.outliers,
  );
  final double q1, median, q3, lowerWhisker, upperWhisker;
  final List<double> outliers;
}

BoxPlotSummary summarizeBoxPlot(List<double> observations) {
  if (observations.isEmpty || observations.any((v) => !v.isFinite)) {
    throw const FormatException('A box plot needs finite observations.');
  }
  final sorted = List<double>.of(observations)..sort();
  double quantile(double p) {
    final index = (sorted.length - 1) * p;
    final fraction = index - index.floor();
    return sorted[index.floor()] * (1 - fraction) +
        sorted[index.ceil()] * fraction;
  }

  final q1 = quantile(.25), q3 = quantile(.75);
  final iqr = q3 - q1;
  final inside = sorted
      .where((v) => v >= q1 - 1.5 * iqr && v <= q3 + 1.5 * iqr)
      .toList();
  return BoxPlotSummary(
    q1,
    quantile(.5),
    q3,
    inside.first,
    inside.last,
    sorted.where((v) => v < inside.first || v > inside.last).toList(),
  );
}
