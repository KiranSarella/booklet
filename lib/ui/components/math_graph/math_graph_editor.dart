import 'dart:convert';

import 'package:flutter/material.dart';

import 'math_graph_document.dart';

class MathGraphFullscreenPreview extends StatelessWidget {
  const MathGraphFullscreenPreview({super.key, required this.state});
  final MathGraphState state;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Math graph preview')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: MathGraphPreview(state: state),
    ),
  );
}

class MathGraphEditor extends StatefulWidget {
  const MathGraphEditor({super.key, required this.state});
  final MathGraphState state;
  @override
  State<MathGraphEditor> createState() => _MathGraphEditorState();
}

class _MathGraphEditorState extends State<MathGraphEditor> {
  late final draft = MathGraphState()..restore(widget.state.toJson());
  late final title = TextEditingController(text: draft.document.title);
  late final ranges = {
    for (final key in ['xMin', 'xMax', 'yMin', 'yMax'])
      key: TextEditingController(text: '${draft.toJson()[key]}'),
  };
  late final equations = draft.document.equations
      .map((e) => TextEditingController(text: e.expression))
      .toList();
  late final visible = draft.document.equations.map((e) => e.visible).toList();
  late String angleUnit = draft.document.degrees ? 'degrees' : 'radians';
  late final raw = TextEditingController(text: encode(draft.toJson()));
  MathGraphTemplate template = MathGraphTemplate.polynomial;
  String? error;
  static String encode(Map<String, dynamic> value) =>
      const JsonEncoder.withIndent('  ').convert(value);
  // TabBarView may retain off-screen equation widgets during transitions.
  // Reuse controllers, including removed rows, until the editor is disposed.
  // The pool is bounded by the maximum of 16 equation rows.
  final spareControllers = <TextEditingController>[];
  void retire(Iterable<TextEditingController> controllers) {
    spareControllers.addAll(controllers);
  }

  TextEditingController equationController(String text) {
    final controller = spareControllers.isEmpty
        ? TextEditingController()
        : spareControllers.removeLast();
    controller.text = text;
    return controller;
  }

  void update() {
    setState(() {
      try {
        final json = <String, dynamic>{
          'title': title.text,
          'angleUnit': angleUnit,
          'equations': List.generate(
            equations.length,
            (i) => {'expression': equations[i].text, 'visible': visible[i]},
          ),
        };
        for (final entry in ranges.entries) {
          final value = double.tryParse(entry.value.text);
          if (value == null || !value.isFinite) {
            throw FormatException('${entry.key} must be a finite number.');
          }
          json[entry.key] = value;
        }
        draft.restore(json);
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
        for (final entry in ranges.entries) {
          entry.value.text = '${draft.toJson()[entry.key]}';
        }
        final next = draft.document.equations;
        for (var i = 0; i < next.length; i++) {
          if (i < equations.length) {
            equations[i].text = next[i].expression;
          } else {
            equations.add(equationController(next[i].expression));
          }
        }
        while (equations.length > next.length) {
          retire([equations.removeLast()]);
        }
        visible
          ..clear()
          ..addAll(draft.document.equations.map((e) => e.visible));
        angleUnit = draft.document.degrees ? 'degrees' : 'radians';
        error = null;
      } on FormatException catch (e) {
        error = e.message;
      }
    });
  }

  @override
  void dispose() {
    for (final c in [
      title,
      raw,
      ...ranges.values,
      ...equations,
      ...spareControllers,
    ]) {
      c.dispose();
    }
    draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Edit math graph'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Preview'),
            Tab(text: 'Equations'),
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
                  child: MathGraphPreview(state: draft),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        key: const ValueKey('math-graph-title'),
                        controller: title,
                        decoration: const InputDecoration(labelText: 'Title'),
                        onChanged: (_) => update(),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          for (final entry in ranges.entries)
                            SizedBox(
                              width: 150,
                              child: TextFormField(
                                key: ValueKey('math-graph-${entry.key}'),
                                controller: entry.value,
                                decoration: InputDecoration(
                                  labelText: switch (entry.key) {
                                    'xMin' => 'X minimum',
                                    'xMax' => 'X maximum',
                                    'yMin' => 'Y minimum',
                                    _ => 'Y maximum',
                                  },
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                      signed: true,
                                    ),
                                onChanged: (_) => update(),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        key: ValueKey(angleUnit),
                        initialValue: angleUnit,
                        decoration: const InputDecoration(
                          labelText: 'Angle unit',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'radians',
                            child: Text('Radians'),
                          ),
                          DropdownMenuItem(
                            value: 'degrees',
                            child: Text('Degrees'),
                          ),
                        ],
                        onChanged: (value) {
                          angleUnit = value!;
                          update();
                        },
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Enter y = f(x), for example x^2, 2x + 1, or sin(x).',
                      ),
                      const Text(
                        'Use + − * / ^ and parentheses. Functions: sin, cos, tan, asin, acos, atan, sqrt, abs, ln, log (base 10), exp. Constants: pi, e.',
                      ),
                      const SizedBox(height: 12),
                      for (var i = 0; i < equations.length; i++)
                        Row(
                          children: [
                            Checkbox(
                              value: visible[i],
                              activeColor:
                                  mathGraphColors[i % mathGraphColors.length],
                              semanticLabel: 'Show equation ${i + 1}',
                              onChanged: (value) {
                                visible[i] = value!;
                                update();
                              },
                            ),
                            Expanded(
                              child: TextFormField(
                                key: ValueKey(equations[i]),
                                controller: equations[i],
                                decoration: InputDecoration(
                                  labelText: 'Equation ${i + 1}',
                                  prefixText: 'y = ',
                                ),
                                onChanged: (_) => update(),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove equation',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: equations.length <= 1
                                  ? null
                                  : () {
                                      retire([equations.removeAt(i)]);
                                      visible.removeAt(i);
                                      update();
                                    },
                            ),
                          ],
                        ),
                      const SizedBox(height: 24),
                      DropdownButtonFormField<MathGraphTemplate>(
                        initialValue: template,
                        decoration: const InputDecoration(
                          labelText: 'Equation starter',
                        ),
                        items: MathGraphTemplate.values
                            .map(
                              (t) => DropdownMenuItem(
                                value: t,
                                child: Text('${t.label}: ${t.expression}'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => template = value!),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Add equation'),
                          onPressed: equations.length >= 16
                              ? null
                              : () {
                                  equations.add(
                                    equationController(template.expression),
                                  );
                                  visible.add(true);
                                  update();
                                },
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: TextField(
                    key: const ValueKey('math-graph-raw-data'),
                    controller: raw,
                    expands: true,
                    minLines: null,
                    maxLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      labelText: 'Math graph JSON',
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
