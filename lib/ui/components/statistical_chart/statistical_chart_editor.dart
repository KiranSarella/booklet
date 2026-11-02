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
  late ChartType selectedType;
  late ChartDataFormat axis;
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
    retire([...labels, ...columns.expand((c) => c), ...names, ...sizes]);
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
    axis.dataKey: labels
        .map(
          (c) => axis == ChartDataFormat.xy ? double.tryParse(c.text) : c.text,
        )
        .toList(),
    'values': columns.first.map((c) => double.tryParse(c.text)).toList(),
    if (axis.supportsSeries) 'metricName': names.first.text,
    if (axis.supportsSeries)
      'series': List.generate(
        columns.length - 1,
        (i) => {
          'name': names[i + 1].text,
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
    if ((type == ChartType.scatter || type == ChartType.bubble) &&
        axis != ChartDataFormat.xy) {
      axis = ChartDataFormat.xy;
    }
    update();
  }

  @override
  void dispose() {
    for (final c in [
      title,
      raw,
      ...labels,
      ...columns.expand((c) => c),
      ...names,
      ...sizes,
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
          if (!selectedType.composition && family != ChartFamily.scatterBubble)
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
                160.0 * (1 + columns.length + (showSizes ? 1 : 0)) + 56,
              ),
              child: Table(
                columnWidths: {
                  1 + columns.length + (showSizes ? 1 : 0):
                      const FixedColumnWidth(56),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                border: TableBorder.all(color: Theme.of(context).dividerColor),
                children: [
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(axis.columnLabel),
                      ),
                      for (var c = 0; c < columns.length; c++)
                        axis.supportsSeries
                            ? Column(
                                children: [
                                  cell(names[c], 'Metric name'),
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
                                        ]);
                                        update();
                                      },
                                    ),
                                ],
                              )
                            : const Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('Value'),
                              ),
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
                        cell(
                          labels[i],
                          axis.columnLabel,
                          numeric: axis == ChartDataFormat.xy,
                        ),
                        for (var c = 0; c < columns.length; c++)
                          cell(
                            columns[c][i],
                            axis.supportsSeries ? names[c].text : 'Value',
                            numeric: true,
                          ),
                        if (showSizes) cell(sizes[i], 'Size', numeric: true),
                        IconButton(
                          tooltip: 'Remove data point',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            retire([
                              labels.removeAt(i),
                              sizes.removeAt(i),
                              for (final col in columns) col.removeAt(i),
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
                      text: axis == ChartDataFormat.xy
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
                  update();
                },
              ),
              if (!selectedType.composition &&
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
