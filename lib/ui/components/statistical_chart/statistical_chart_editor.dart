import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'statistical_chart_document.dart';

class StatisticalChartFullscreenPreview extends StatelessWidget {
  const StatisticalChartFullscreenPreview({super.key, required this.state});
  final StatisticalChartState state;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Statistical chart preview')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: StatisticalChartPreview(state: state),
    ),
  );
}

class StatisticalChartEditor extends StatefulWidget {
  const StatisticalChartEditor({super.key, required this.state});
  final StatisticalChartState state;
  @override
  State<StatisticalChartEditor> createState() => _StatisticalChartEditorState();
}

class _StatisticalChartEditorState extends State<StatisticalChartEditor> {
  late final draft = StatisticalChartState()..restore(widget.state.toJson());
  late final title = TextEditingController(text: draft.title);
  late final raw = TextEditingController(text: encode(draft.toJson()));
  final labels = <TextEditingController>[];
  final columns = <List<TextEditingController>>[];
  final names = <TextEditingController>[];
  final sizes = <TextEditingController>[];
  final bounds = <List<TextEditingController>>[];
  final styles = <String>[];
  late bool intervals = draft.showIntervals;
  late bool hasIntervalBounds = draft.lower.isNotEmpty || draft.showIntervals;
  bool get isBoxPlot => selectedType == ChartType.boxPlot;
  bool get supportsIntervals => selectedType.supportsIntervals;
  late ChartType selectedType;
  late ChartDataFormat axis;
  late int? binCount = draft.histogramBinCount;
  final pastedValues = TextEditingController();
  String? pasteError;
  bool get isHistogram => selectedType == ChartType.histogram;
  ChartFamily get family => ChartFamily.forType(selectedType);
  bool rawInvalid = false;
  String? error;
  static String encode(Map<String, dynamic> json) =>
      const JsonEncoder.withIndent('  ').convert(json);
  bool get showSizes =>
      axis == ChartDataFormat.xy && selectedType == ChartType.bubble;
  @override
  void initState() {
    super.initState();
    selectedType = draft.type == ChartType.bar
        ? ChartType.column
        : draft.type == ChartType.multiLine
        ? ChartType.line
        : draft.type;
    axis =
        [
          ChartDataFormat.grouped,
          ChartDataFormat.composition,
        ].contains(draft.category)
        ? ChartDataFormat.categorical
        : draft.category;
    if (draft.category == ChartDataFormat.grouped &&
        draft.labels.isNotEmpty &&
        draft.labels.every(ChartDataFormat.validDate)) {
      axis = ChartDataFormat.timeSeries;
    }
    draft.type = selectedType;
    draft.category = axis;
    raw.text = encode(draft.toJson());
    replaceFields();
  }

  void retire(Iterable<TextEditingController> controllers) {
    final old = controllers.toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in old) {
        c.dispose();
      }
    });
  }

  void replaceFields() {
    retire([
      ...labels,
      ...columns.expand((c) => c),
      ...names,
      ...sizes,
      ...bounds.expand((b) => b),
    ]);
    labels
      ..clear()
      ..addAll(draft.labels.map((v) => TextEditingController(text: v)));
    columns
      ..clear()
      ..addAll(
        draft.metrics.map(
          (m) => m.values
              .map((v) => TextEditingController(text: v.toString()))
              .toList(),
        ),
      );
    names
      ..clear()
      ..addAll(draft.metrics.map((m) => TextEditingController(text: m.name)));
    sizes
      ..clear()
      ..addAll(
        List.generate(
          labels.length,
          (i) => TextEditingController(
            text: draft.bubbleSizes.length == labels.length
                ? '${draft.bubbleSizes[i]}'
                : '1',
          ),
        ),
      );
    bounds.clear();
    styles.clear();
    for (final metric in draft.metrics) {
      styles.add(metric.style);
      bounds.add(
        List.generate(
          labels.length,
          (i) => TextEditingController(
            text:
                '${metric.lower.length == labels.length ? metric.lower[i] : metric.values[i]}',
          ),
        ),
      );
      bounds.add(
        List.generate(
          labels.length,
          (i) => TextEditingController(
            text:
                '${metric.upper.length == labels.length ? metric.upper[i] : metric.values[i]}',
          ),
        ),
      );
    }
    title.text = draft.title;
  }

  void syncRaw() {
    raw.text = encode(draft.toJson());
    error = null;
    rawInvalid = false;
  }

  Map<String, dynamic> tableJson() => {
    'datasetFormat': axis.name,
    'graphType': selectedType.name,
    'title': title.text,
    'primaryStyle': styles.first,
    'showIntervals': intervals,
    if (intervals)
      'lower': bounds[0].map((c) => double.tryParse(c.text)).toList(),
    if (intervals)
      'upper': bounds[1].map((c) => double.tryParse(c.text)).toList(),
    axis.dataKey: labels
        .map(
          (c) => axis == ChartDataFormat.xy ? double.tryParse(c.text) : c.text,
        )
        .toList(),
    'values': columns.first.map((c) => double.tryParse(c.text)).toList(),
    'binCount': binCount,
    if (axis.supportsSeries) 'metricName': names.first.text,
    if (axis.supportsSeries)
      'series': List.generate(
        columns.length - 1,
        (i) => {
          'name': names[i + 1].text,
          'style': styles[i + 1],
          if (intervals)
            'lower': bounds[(i + 1) * 2]
                .map((c) => double.tryParse(c.text))
                .toList(),
          if (intervals)
            'upper': bounds[(i + 1) * 2 + 1]
                .map((c) => double.tryParse(c.text))
                .toList(),
          'values': columns[i + 1].map((c) => double.tryParse(c.text)).toList(),
        },
      ),
    if (axis == ChartDataFormat.xy)
      'sizes': sizes.map((c) => double.tryParse(c.text)).toList(),
  };
  void update() {
    setState(() {
      try {
        if (labels.any((c) => !axis.validLabel(c.text))) {
          throw FormatException(
            axis == ChartDataFormat.xy
                ? 'Enter a number in each X cell in Data set. For named items, choose a Bar or Line chart and set Horizontal axis to Text labels.'
                : 'Enter dates in YYYY-MM-DD format in the first column.',
          );
        }
        final json = tableJson();
        StatisticalChartState.validateJson(json);
        draft.restore(json);
        syncRaw();
      } on FormatException catch (e) {
        error = e.message;
      }
    });
  }

  void updateRaw(String text) {
    setState(() {
      try {
        final json = jsonDecode(text);
        if (json is! Map<String, dynamic>) {
          throw const FormatException('Expected a JSON object.');
        }
        StatisticalChartState.validateJson(json);
        draft.restore(json);
        selectedType = draft.type;
        axis = draft.category;
        binCount = draft.histogramBinCount;
        intervals = draft.showIntervals;
        hasIntervalBounds = draft.lower.isNotEmpty || draft.showIntervals;
        replaceFields();
        error = null;
        rawInvalid = false;
      } on FormatException catch (e) {
        error = e.message;
        rawInvalid = true;
      }
    });
  }

  void changeAxis(ChartDataFormat category) {
    // Keep entered text and every value column; invalid X values can be fixed
    // directly in the table rather than replacing the dataset with samples.
    axis = category;
    update();
  }

  void chooseType(ChartType type) {
    if (rawInvalid) return;
    selectedType = type;
    if (!supportsIntervals) intervals = false;
    if (type == ChartType.histogram || type == ChartType.boxPlot) {
      axis = ChartDataFormat.observations;
    } else if (axis == ChartDataFormat.observations) {
      axis = ChartDataFormat.categorical;
    }
    if ((type == ChartType.scatter || type == ChartType.bubble) &&
        axis != ChartDataFormat.xy) {
      axis = ChartDataFormat.xy;
    }
    update();
  }

  void addPastedValues() {
    final text = pastedValues.text.trim();
    final parsed = text.isEmpty
        ? <double?>[]
        : text
              .split(RegExp(r'[\s,;]+'))
              .where((v) => v.isNotEmpty)
              .map(double.tryParse)
              .toList();
    if (parsed.isEmpty || parsed.any((v) => v == null || !v.isFinite)) {
      setState(
        () => pasteError = 'Enter finite numbers separated by spaces, commas, semicolons, or new lines.',
      );
      return;
    }
    for (final value in parsed) {
      labels.add(TextEditingController(text: '${labels.length + 1}'));
      columns.first.add(TextEditingController(text: '$value'));
      sizes.add(TextEditingController(text: '1'));
      for (final b in bounds) {
        b.add(TextEditingController(text: '$value'));
      }
    }
    pastedValues.clear();
    pasteError = null;
    update();
  }

  @override
  void dispose() {
    for (final c in [
      title,
      raw,
      pastedValues,
      ...labels,
      ...columns.expand((c) => c),
      ...names,
      ...sizes,
      ...bounds.expand((b) => b),
    ]) {
      c.dispose();
    }
    draft.dispose();
    super.dispose();
  }

  Widget cell(
    TextEditingController controller,
    String label, {
    bool numeric = false,
  }) => Padding(
    padding: const EdgeInsets.all(8),
    child: Semantics(
      label: label,
      child: TextFormField(
        controller: controller,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
        ),
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true, signed: true)
            : TextInputType.text,
        onChanged: (_) => update(),
      ),
    ),
  );
  Widget dataset() => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isHistogram &&
              !isBoxPlot &&
              !selectedType.composition &&
              family != ChartFamily.scatterBubble)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: DropdownButtonFormField<ChartDataFormat>(
                key: ValueKey(axis),
                initialValue:
                    [
                      ChartDataFormat.grouped,
                      ChartDataFormat.composition,
                    ].contains(axis)
                    ? ChartDataFormat.categorical
                    : axis,
                decoration: const InputDecoration(labelText: 'Horizontal axis'),
                items:
                    [
                          ChartDataFormat.categorical,
                          ChartDataFormat.timeSeries,
                          ChartDataFormat.xy,
                        ]
                        .map(
                          (c) =>
                              DropdownMenuItem(value: c, child: Text(c.label)),
                        )
                        .toList(),
                onChanged: rawInvalid ? null : (value) => changeAxis(value!),
              ),
            ),
          if (isBoxPlot)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Enter one observation per row. Repeat a group label to collect observations in the same box. Quartiles use inclusive percentiles; whiskers use 1.5 × IQR fences.',
              ),
            ),
          if (selectedType == ChartType.combo)
            const Text(
              'Choose Column or Line for each value column. Both use the same vertical scale.',
            ),
          if (supportsIntervals)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Error bars / confidence intervals'),
              subtitle: const Text(
                'Enter calculated lower and upper bounds; confidence levels are not calculated automatically.',
              ),
              value: intervals,
              onChanged: rawInvalid
                  ? null
                  : (v) {
                      intervals = v!;
                      if (intervals && !hasIntervalBounds) {
                        for (var c = 0; c < columns.length; c++) {
                          for (var i = 0; i < labels.length; i++) {
                            bounds[c * 2][i].text = columns[c][i].text;
                            bounds[c * 2 + 1][i].text = columns[c][i].text;
                          }
                        }
                        hasIntervalBounds = true;
                      }
                      update();
                    },
            ),
          if (isHistogram) ...[
            const Text(
              'Enter the original numeric observations, one per row. The chart calculates frequencies; do not enter pre-counted frequencies.',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: ValueKey(('histogram-bins', binCount)),
              initialValue: binCount ?? 0,
              decoration: const InputDecoration(labelText: 'Number of bins'),
              items: [
                const DropdownMenuItem(value: 0, child: Text('Auto')),
                for (var i = 1; i <= 100; i++)
                  DropdownMenuItem(value: i, child: Text('$i bins')),
              ],
              onChanged: rawInvalid
                  ? null
                  : (value) {
                      binCount = value == 0 ? null : value;
                      update();
                    },
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('histogram-paste-values'),
              controller: pastedValues,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Paste observations',
                hintText: '12, 15, 15, 18, 22',
                errorText: pasteError,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() => pasteError = null),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: columns.length == 1 && !rawInvalid
                    ? addPastedValues
                    : null,
                icon: const Icon(Icons.playlist_add),
                label: const Text('Add values'),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (selectedType.composition)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Enter non-negative amounts or percentages. Shares are calculated from the total.',
              ),
            ),
          if (showSizes)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Bubble area represents Size. Enter another measurement here; equal values produce equal-size bubbles.',
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: math.max(
                constraints.maxWidth - 32,
                160.0 *
                        ((isHistogram ? 0 : 1) +
                            columns.length * (intervals ? 3 : 1) +
                            (showSizes ? 1 : 0)) +
                    56,
              ),
              child: Table(
                columnWidths: {
                  (isHistogram ? 0 : 1) +
                      columns.length * (intervals ? 3 : 1) +
                      (showSizes ? 1 : 0): const FixedColumnWidth(
                    56,
                  ),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                border: TableBorder.all(color: Theme.of(context).dividerColor),
                children: [
                  TableRow(
                    children: [
                      if (!isHistogram)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(isBoxPlot ? 'Group' : axis.columnLabel),
                        ),
                      for (var c = 0; c < columns.length; c++) ...[
                        axis.supportsSeries
                            ? Column(
                                children: [
                                  cell(names[c], 'Metric name'),
                                  if (selectedType == ChartType.combo)
                                    DropdownButton<String>(
                                      value: styles[c],
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'column',
                                          child: Text('Column'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'line',
                                          child: Text('Line'),
                                        ),
                                      ],
                                      onChanged: rawInvalid
                                          ? null
                                          : (v) {
                                              styles[c] = v!;
                                              update();
                                            },
                                    ),
                                  if (columns.length > 1)
                                    IconButton(
                                      tooltip: 'Remove value column',
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                      onPressed: () {
                                        retire([
                                          names.removeAt(c),
                                          ...columns.removeAt(c),
                                          ...bounds.removeAt(c * 2),
                                          ...bounds.removeAt(c * 2),
                                        ]);
                                        styles.removeAt(c);
                                        update();
                                      },
                                    ),
                                ],
                              )
                            : const Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('Value'),
                              ),
                        if (intervals)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('Lower bound'),
                          ),
                        if (intervals)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('Upper bound'),
                          ),
                      ],
                      if (showSizes)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('Size'),
                        ),
                      const SizedBox(),
                    ],
                  ),
                  for (var i = 0; i < labels.length; i++)
                    TableRow(
                      children: [
                        if (!isHistogram)
                          cell(
                            labels[i],
                            isBoxPlot ? 'Group' : axis.columnLabel,
                            numeric: axis == ChartDataFormat.xy,
                          ),
                        for (var c = 0; c < columns.length; c++) ...[
                          cell(
                            columns[c][i],
                            axis.supportsSeries ? names[c].text : 'Value',
                            numeric: true,
                          ),
                          if (intervals)
                            cell(
                              bounds[c * 2][i],
                              'Lower bound',
                              numeric: true,
                            ),
                          if (intervals)
                            cell(
                              bounds[c * 2 + 1][i],
                              'Upper bound',
                              numeric: true,
                            ),
                        ],
                        if (showSizes) cell(sizes[i], 'Size', numeric: true),
                        IconButton(
                          tooltip: 'Remove data point',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            retire([
                              labels.removeAt(i),
                              sizes.removeAt(i),
                              for (final col in columns) col.removeAt(i),
                              for (final b in bounds) b.removeAt(i),
                            ]);
                            update();
                          },
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          Wrap(
            spacing: 16,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add data point'),
                onPressed: () {
                  labels.add(
                    TextEditingController(
                      text: axis == ChartDataFormat.xy || isHistogram
                          ? '${labels.length + 1}'
                          : axis == ChartDataFormat.timeSeries
                          ? DateTime.now().toIso8601String().substring(0, 10)
                          : '',
                    ),
                  );
                  for (final col in columns) {
                    col.add(TextEditingController(text: '0'));
                  }
                  sizes.add(TextEditingController(text: '1'));
                  for (final b in bounds) {
                    b.add(TextEditingController(text: '0'));
                  }
                  update();
                },
              ),
              if (!isHistogram &&
                  !isBoxPlot &&
                  !selectedType.composition &&
                  family != ChartFamily.scatterBubble)
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add value column'),
                  onPressed: () {
                    names.add(
                      TextEditingController(
                        text: 'Metric ${columns.length + 1}',
                      ),
                    );
                    columns.add(
                      List.generate(
                        labels.length,
                        (_) => TextEditingController(text: '0'),
                      ),
                    );
                    styles.add('line');
                    bounds.add(
                      List.generate(
                        labels.length,
                        (_) => TextEditingController(text: '0'),
                      ),
                    );
                    bounds.add(
                      List.generate(
                        labels.length,
                        (_) => TextEditingController(text: '0'),
                      ),
                    );
                    update();
                  },
                ),
            ],
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Edit statistical chart'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Preview'),
            Tab(text: 'Data set'),
            Tab(text: 'Raw data'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: error != null
                ? null
                : () {
                    try {
                      StatisticalChartState.validateJson(draft.toJson());
                      widget.state.restore(draft.toJson());
                      Navigator.of(context).pop();
                    } on FormatException catch (e) {
                      setState(() => error = e.message);
                    }
                  },
            child: const Text('Save'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              children: [
                DropdownButtonFormField<ChartFamily>(
                  key: ValueKey(family),
                  initialValue: family,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Chart group'),
                  items: ChartFamily.values
                      .map(
                        (f) => DropdownMenuItem(value: f, child: Text(f.label)),
                      )
                      .toList(),
                  onChanged: rawInvalid
                      ? null
                      : (value) => chooseType(value!.types.first),
                ),
                DropdownButtonFormField<ChartType>(
                  key: ValueKey(selectedType),
                  initialValue: selectedType,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Chart type'),
                  items: {...family.types, selectedType}
                      .map(
                        (t) => DropdownMenuItem(value: t, child: Text(t.label)),
                      )
                      .toList(),
                  onChanged: rawInvalid ? null : (value) => chooseType(value!),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(family.description),
                  ),
                ),
                TextFormField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title'),
                  onChanged: (_) => update(),
                ),
              ],
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: TabBarView(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: StatisticalChartPreview(state: draft),
                ),
                dataset(),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: TextField(
                    key: const ValueKey('statistical-chart-raw-data'),
                    controller: raw,
                    expands: true,
                    minLines: null,
                    maxLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Chart JSON',
                      alignLabelWithHint: true,
                    ),
                    onChanged: updateRaw,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
