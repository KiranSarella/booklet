import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'gantt_chart_document.dart';

class GanttChartFullscreenPreview extends StatelessWidget {
  const GanttChartFullscreenPreview({super.key, required this.state});
  final GanttChartState state;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Gantt chart preview')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: GanttChartPreview(state: state),
    ),
  );
}

class GanttChartEditor extends StatefulWidget {
  const GanttChartEditor({super.key, required this.state});
  final GanttChartState state;
  @override
  State<GanttChartEditor> createState() => _GanttChartEditorState();
}

class _TaskInputs {
  String id = '';
  final title = TextEditingController(),
      start = TextEditingController(),
      end = TextEditingController(),
      progress = TextEditingController(),
      baselineStart = TextEditingController(),
      baselineEnd = TextEditingController();
  Set<String> dependencies = {};
  void load(GanttTask task) {
    id = task.id;
    title.text = task.title;
    start.text = ganttDate(task.start);
    end.text = ganttDate(task.end);
    progress.text = '${task.progress}';
    baselineStart.text = task.baselineStart == null
        ? ''
        : ganttDate(task.baselineStart!);
    baselineEnd.text = task.baselineEnd == null
        ? ''
        : ganttDate(task.baselineEnd!);
    dependencies = task.dependencies.toSet();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title.text,
    'start': start.text,
    'end': end.text,
    'progress': double.tryParse(progress.text),
    'dependencies': dependencies.toList(),
    if (baselineStart.text.isNotEmpty || baselineEnd.text.isNotEmpty) ...{
      'baselineStart': baselineStart.text,
      'baselineEnd': baselineEnd.text,
    },
  };
  void dispose() {
    title.dispose();
    start.dispose();
    end.dispose();
    progress.dispose();
    baselineStart.dispose();
    baselineEnd.dispose();
  }
}

class _GanttChartEditorState extends State<GanttChartEditor> {
  late final draft = GanttChartState()..restore(widget.state.toJson());
  late final title = TextEditingController(text: draft.document.title);
  late final raw = TextEditingController(text: encode(draft.toJson()));
  late GanttScale scale = draft.document.scale;
  late GanttChartType type = draft.document.type;
  bool get tracking => type == GanttChartType.tracking;
  final rows = <_TaskInputs>[];
  // TabBarView retains hidden fields. Reuse row controllers until editor exit.
  final spareRows = <_TaskInputs>[];
  String? error;
  static String encode(Map<String, dynamic> json) =>
      const JsonEncoder.withIndent('  ').convert(json);
  @override
  void initState() {
    super.initState();
    loadRows();
  }

  void loadRows() {
    final nextIds = draft.document.tasks.map((t) => t.id).toSet();
    final existing = {
      for (final row in rows)
        if (nextIds.contains(row.id)) row.id: row,
    };
    spareRows.addAll(rows.where((r) => !nextIds.contains(r.id)));
    rows.clear();
    for (final task in draft.document.tasks) {
      final row =
          existing[task.id] ??
          (spareRows.isEmpty ? _TaskInputs() : spareRows.removeLast());
      row.load(task);
      rows.add(row);
    }
  }

  void update() {
    setState(() {
      try {
        draft.restore({
          'title': title.text,
          'timelineScale': scale.name,
          'chartType': type.name,
          'tasks': rows.map((r) => r.toJson()).toList(),
        });
        raw.text = encode(draft.toJson());
        error = null;
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
        draft.restore(json);
        title.text = draft.document.title;
        scale = draft.document.scale;
        type = draft.document.type;
        loadRows();
        error = null;
      } on FormatException catch (e) {
        error = e.message;
      }
    });
  }

  void captureBaseline() {
    for (final row in rows) {
      row.baselineStart.text = row.start.text;
      row.baselineEnd.text = row.end.text;
    }
    update();
  }

  void addTask() {
    final last = draft.document.tasks
        .map((t) => t.end)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    var start = last.add(const Duration(days: 1)),
        end = last.add(const Duration(days: 3));
    if (end.year > 9999) {
      start = last;
      end = last;
    }
    final row = spareRows.isEmpty ? _TaskInputs() : spareRows.removeLast();
    row.load(
      GanttTask(
        id: const Uuid().v4(),
        title: 'New task',
        start: start,
        end: end,
      ),
    );
    rows.add(row);
    update();
  }

  void removeTask(int index) {
    final row = rows.removeAt(index);
    spareRows.add(row);
    for (final task in rows) {
      task.dependencies.remove(row.id);
    }
    update();
  }

  void moveTask(int index, int direction) {
    final row = rows.removeAt(index);
    rows.insert(index + direction, row);
    update();
  }

  Future<void> pickDate(
    _TaskInputs row,
    TextEditingController controller,
  ) async {
    DateTime date;
    try {
      date = parseGanttDate(controller.text);
    } on FormatException {
      date = DateTime.now();
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(date.year, date.month, date.day),
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
    );
    if (!mounted || picked == null || !rows.contains(row)) return;
    controller.text = ganttDate(picked);
    update();
  }

  Widget field(
    TextEditingController controller,
    String label, {
    bool numeric = false,
    _TaskInputs? row,
  }) => Padding(
    padding: const EdgeInsets.all(8),
    child: Semantics(
      label: label,
      child: TextFormField(
        key: ValueKey(controller),
        controller: controller,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          suffixText: numeric ? '%' : null,
          suffixIcon: row == null
              ? null
              : IconButton(
                  tooltip: 'Choose $label',
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  onPressed: () => pickDate(row, controller),
                ),
        ),
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        onChanged: (_) => update(),
      ),
    ),
  );
  Widget dependencyPicker(_TaskInputs row) {
    final selected = rows
        .where((r) => row.dependencies.contains(r.id))
        .map((r) => r.title.text)
        .join(', ');
    return PopupMenuButton<String>(
      tooltip: 'Choose dependencies for ${row.title.text}',
      enabled: rows.length > 1,
      itemBuilder: (_) => [
        for (var i = 0; i < rows.length; i++)
          if (rows[i] != row)
            CheckedPopupMenuItem(
              value: rows[i].id,
              checked: row.dependencies.contains(rows[i].id),
              child: Text('${i + 1}. ${rows[i].title.text}'),
            ),
      ],
      onSelected: (id) {
        if (!row.dependencies.remove(id)) row.dependencies.add(id);
        update();
      },
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selected.isEmpty ? 'None' : selected,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final row in [...rows, ...spareRows]) {
      row.dispose();
    }
    title.dispose();
    raw.dispose();
    draft.dispose();
    super.dispose();
  }

  Widget tasks() => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            key: const ValueKey('gantt-title'),
            controller: title,
            decoration: const InputDecoration(labelText: 'Chart title'),
            onChanged: (_) => update(),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<GanttScale>(
            key: ValueKey(scale),
            initialValue: scale,
            decoration: const InputDecoration(labelText: 'Timeline labels'),
            items: GanttScale.values
                .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                .toList(),
            onChanged: (value) {
              scale = value!;
              update();
            },
          ),
          const SizedBox(height: 16),
          if (tracking) ...[
            const Text(
              'Tracking Gantt compares baseline dates with the current schedule. Capture the current plan once, then edit current dates; the baseline stays unchanged.',
            ),
            Wrap(
              spacing: 12,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Capture baseline'),
                  onPressed: error != null ? null : captureBaseline,
                ),
                TextButton(
                  onPressed: () {
                    for (final row in rows) {
                      row.baselineStart.clear();
                      row.baselineEnd.clear();
                    }
                    update();
                  },
                  child: const Text('Clear baseline'),
                ),
              ],
            ),
          ],
          const Text(
            'Dates include both the start and end day. Dependencies mean a task should start after its predecessors finish. Scheduling conflicts are shown in the preview; dates are never moved automatically.',
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: math.max(
                constraints.maxWidth - 48,
                tracking ? 1400 : 1060,
              ),
              child: Table(
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                columnWidths: {
                  0: const FixedColumnWidth(220),
                  1: const FixedColumnWidth(170),
                  2: const FixedColumnWidth(170),
                  if (tracking) ...{
                    3: const FixedColumnWidth(170),
                    4: const FixedColumnWidth(170),
                  },
                  tracking ? 5 : 3: const FixedColumnWidth(100),
                  tracking ? 7 : 5: const FixedColumnWidth(152),
                },
                border: TableBorder.all(color: Theme.of(context).dividerColor),
                children: [
                  TableRow(
                    children: [
                      for (final label in [
                        'Task',
                        'Start (YYYY-MM-DD)',
                        'End (YYYY-MM-DD)',
                        if (tracking) ...[
                          'Baseline start (YYYY-MM-DD)',
                          'Baseline end (YYYY-MM-DD)',
                        ],
                        'Progress',
                        'Depends on',
                        'Actions',
                      ])
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            label,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                  for (var i = 0; i < rows.length; i++)
                    TableRow(
                      key: ValueKey(rows[i].id),
                      children: [
                        field(rows[i].title, 'Task ${i + 1} name'),
                        field(
                          rows[i].start,
                          'Task ${i + 1} start date',
                          row: rows[i],
                        ),
                        field(
                          rows[i].end,
                          'Task ${i + 1} end date',
                          row: rows[i],
                        ),
                        if (tracking) ...[
                          field(
                            rows[i].baselineStart,
                            'Task ${i + 1} baseline start date',
                            row: rows[i],
                          ),
                          field(
                            rows[i].baselineEnd,
                            'Task ${i + 1} baseline end date',
                            row: rows[i],
                          ),
                        ],
                        field(
                          rows[i].progress,
                          'Task ${i + 1} progress',
                          numeric: true,
                        ),
                        dependencyPicker(rows[i]),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              tooltip: 'Move task up',
                              icon: const Icon(Icons.arrow_upward, size: 18),
                              onPressed: i == 0 ? null : () => moveTask(i, -1),
                            ),
                            IconButton(
                              tooltip: 'Move task down',
                              icon: const Icon(Icons.arrow_downward, size: 18),
                              onPressed: i == rows.length - 1
                                  ? null
                                  : () => moveTask(i, 1),
                            ),
                            IconButton(
                              tooltip: 'Remove task',
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: rows.length <= 1
                                  ? null
                                  : () => removeTask(i),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add task'),
              onPressed: rows.length >= 100 ? null : addTask,
            ),
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
        title: const Text('Edit Gantt chart'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Preview'),
            Tab(text: 'Tasks'),
            Tab(text: 'Raw data'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: error != null
                ? null
                : () {
                    widget.state.restore(draft.toJson());
                    Navigator.of(context).pop();
                  },
            child: const Text('Save'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: DropdownButtonFormField<GanttChartType>(
              key: ValueKey(type),
              initialValue: type,
              decoration: const InputDecoration(labelText: 'Chart type'),
              items: GanttChartType.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                  .toList(),
              onChanged: (value) {
                type = value!;
                update();
              },
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(12),
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
                  child: GanttChartPreview(state: draft),
                ),
                tasks(),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: TextField(
                    key: const ValueKey('gantt-raw-data'),
                    controller: raw,
                    expands: true,
                    minLines: null,
                    maxLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      labelText: 'Gantt chart JSON',
                      border: OutlineInputBorder(),
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
