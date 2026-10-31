import 'dart:convert';

import 'package:flutter/material.dart';

import 'table_document.dart';

class TableEditor extends StatefulWidget {
  const TableEditor({super.key, required this.state});
  final TableComponentState state;
  @override
  State<TableEditor> createState() => _TableEditorState();
}

class _TableEditorState extends State<TableEditor> {
  late final TableComponentState draft = widget.state.clone();
  final controller = TextEditingController();
  final List<String> undo = [], redo = [];
  int row = 0, column = 0;
  bool closing = false;
  String get snapshot => jsonEncode(draft.toJson());
  TableCellData get cell => draft.rows[row][column];
  @override
  void initState() {
    super.initState();
    controller.text = cell.text;
  }

  void change(VoidCallback action) {
    undo.add(snapshot);
    redo.clear();
    setState(action);
  }

  void select(int r, int c) => setState(() {
    row = r;
    column = c;
    controller.text = cell.text;
  });
  void history(List<String> source, List<String> target) {
    if (source.isEmpty) return;
    target.add(snapshot);
    setState(() {
      draft.restore(
        Map<String, dynamic>.from(jsonDecode(source.removeLast()) as Map),
      );
      row = row.clamp(0, draft.rows.length - 1);
      column = column.clamp(0, draft.columnCount - 1);
      controller.text = cell.text;
    });
  }

  Future<void> close() async {
    if (snapshot != jsonEncode(widget.state.toJson())) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard table changes?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }
    if (mounted) {
      setState(() => closing = true);
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: closing,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) close();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close table',
          icon: const Icon(Icons.close),
          onPressed: close,
        ),
        title: const Text('Edit table'),
        actions: [
          IconButton(
            tooltip: 'Undo',
            onPressed: undo.isEmpty ? null : () => history(undo, redo),
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'Redo',
            onPressed: redo.isEmpty ? null : () => history(redo, undo),
            icon: const Icon(Icons.redo),
          ),
          TextButton(
            onPressed: () {
              widget.state.restore(draft.toJson());
              setState(() => closing = true);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 108,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final item in <(String, VoidCallback)>[
                      ('Row above', () => draft.insertRow(row)),
                      ('Row below', () => draft.insertRow(row + 1)),
                      ('Column left', () => draft.insertColumn(column)),
                      ('Column right', () => draft.insertColumn(column + 1)),
                      (
                        'Delete row',
                        () {
                          draft.removeRow(row);
                          row = row.clamp(0, draft.rows.length - 1);
                          controller.text = cell.text;
                        },
                      ),
                      (
                        'Delete column',
                        () {
                          draft.removeColumn(column);
                          column = column.clamp(0, draft.columnCount - 1);
                          controller.text = cell.text;
                        },
                      ),
                      (
                        'Clear cell',
                        () {
                          cell.text = '';
                          controller.clear();
                        },
                      ),
                    ])
                      TextButton(
                        onPressed: () => change(item.$2),
                        child: Text(item.$1),
                      ),
                    FilterChip(
                      label: const Text('Header row'),
                      selected: draft.header,
                      onSelected: (v) => change(() => draft.header = v),
                    ),
                    FilterChip(
                      label: const Text('Borders'),
                      selected: draft.borders,
                      onSelected: (v) => change(() => draft.borders = v),
                    ),
                    FilterChip(
                      label: const Text('Striped rows'),
                      selected: draft.striped,
                      onSelected: (v) => change(() => draft.striped = v),
                    ),
                    DropdownButton<double>(
                      value: draft.columnWidth,
                      items:
                          {
                                80.0,
                                120.0,
                                160.0,
                                240.0,
                                320.0,
                                400.0,
                                draft.columnWidth,
                              }
                              .map(
                                (v) => DropdownMenuItem(
                                  value: v,
                                  child: Text('Base width ${v.toInt()}'),
                                ),
                              )
                              .toList(),
                      onChanged: (v) {
                        if (v != null) change(() => draft.columnWidth = v);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TableScrollView(
                width: draft.tableWidth,
                scrollVertically: true,
                child: TablePreview(
                  state: draft,
                  onCell: select,
                  selectedRow: row,
                  selectedColumn: column,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('Row ${row + 1}, column ${column + 1}'),
                      DropdownButton<double>(
                        key: const ValueKey('column-width-percentage'),
                        value: draft.columnWidthPercentage(column),
                        items:
                            {
                                  10.0,
                                  25.0,
                                  50.0,
                                  60.0,
                                  75.0,
                                  100.0,
                                  120.0,
                                  150.0,
                                  200.0,
                                  300.0,
                                  draft.columnWidthPercentage(column),
                                }
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(
                                      'Column width ${value.toStringAsFixed(0)}%',
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            change(
                              () =>
                                  draft.setColumnWidthPercentage(column, value),
                            );
                          }
                        },
                      ),
                      FilterChip(
                        label: const Text('Bold'),
                        selected: cell.bold,
                        onSelected: (v) => change(() => cell.bold = v),
                      ),
                      FilterChip(
                        label: const Text('Italic'),
                        selected: cell.italic,
                        onSelected: (v) => change(() => cell.italic = v),
                      ),
                      for (final a in [
                        TextAlign.left,
                        TextAlign.center,
                        TextAlign.right,
                      ])
                        ChoiceChip(
                          label: Text(a.name),
                          selected: cell.alignment == a,
                          onSelected: (_) => change(() => cell.alignment = a),
                        ),
                      DropdownButton<int>(
                        value: cell.color ?? 0,
                        items: [
                          const DropdownMenuItem(
                            value: 0,
                            child: Text('No fill'),
                          ),
                          for (final entry in <String, Color>{
                            'Yellow': Colors.yellow.shade100,
                            'Blue': Colors.blue.shade100,
                            'Green': Colors.green.shade100,
                            'Pink': Colors.pink.shade100,
                          }.entries)
                            DropdownMenuItem(
                              value: entry.value.toARGB32(),
                              child: Text(entry.key),
                            ),
                          if (cell.color != null &&
                              ![
                                Colors.yellow.shade100,
                                Colors.blue.shade100,
                                Colors.green.shade100,
                                Colors.pink.shade100,
                              ].any((v) => v.toARGB32() == cell.color))
                            DropdownMenuItem(
                              value: cell.color,
                              child: const Text('Custom'),
                            ),
                        ],
                        onChanged: (v) =>
                            change(() => cell.color = v == 0 ? null : v),
                      ),
                    ],
                  ),
                  TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Cell text',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => change(() => cell.text = v),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
