import 'package:booklet/ui/components/focus_bar.dart';
import 'package:booklet/application/page_settings_controller.dart';

import 'composition_preview.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:booklet/ui/components/inbuilt_components/inbuilt_components.dart';

import 'composition.dart';

class CompositionCanvas extends StatefulWidget {
  const CompositionCanvas({super.key, this.initialTemplate, this.theme});
  final PageSettingsController? theme;
  final CompositionTemplate? initialTemplate;
  @override
  State<CompositionCanvas> createState() => _CompositionCanvasState();
}

class _CompositionCanvasState extends State<CompositionCanvas> {
  final name = TextEditingController();
  late final CompositionNode root;
  late CompositionNode selected = root;
  bool saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final initial = widget.initialTemplate;
    root = initial == null
        ? CompositionNode('column', children: [])
        : CompositionNode.fromJson(initial.root.toJson());
    name.text = initial?.name ?? '';
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  void add(String kind, CompositionNode target) => setState(() {
    final node = CompositionNode(kind, children: []);
    target.children = [...target.children, node];
    selected = node;
  });
  void remove(CompositionNode parent, CompositionNode target) {
    parent.children = parent.children.where((e) => e != target).toList();
    for (final child in parent.children) {
      remove(child, target);
    }
  }

  Widget paletteItem(String kind, String label, IconData icon) =>
      Draggable<String>(
        data: kind,
        feedback: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(8),
          child: Padding(padding: const EdgeInsets.all(16), child: Text(label)),
        ),
        child: ListTile(
          dense: true,
          leading: Icon(icon, size: 18),
          title: Text(label),
          onTap: () => add(kind, selected.isLayout ? selected : root),
        ),
      );
  Widget nodeView(CompositionNode node, {double minHeight = 80}) {
    final active = selected == node;
    Widget body;
    if (node.isLayout) {
      final children = <Widget>[];
      final isRow = node.kind == 'row';
      final contentMinimum = math.max(
        0.0,
        minHeight - node.verticalPadding * 2 - 20,
      );
      final available = math.max(
        0.0,
        contentMinimum - node.spacing * math.max(0, node.children.length - 1),
      );
      final total = node.children.fold(
        0.0,
        (sum, child) => sum + child.percent,
      );
      for (final child in node.children) {
        if (children.isNotEmpty) {
          children.add(SizedBox(width: node.spacing, height: node.spacing));
        }
        final preview = nodeView(
          child,
          minHeight: math.max(
            80.0,
            isRow ? contentMinimum : available * child.percent / total,
          ),
        );
        children.add(
          isRow
              ? Expanded(flex: (child.percent * 100).round(), child: preview)
              : preview,
        );
      }
      body = DragTarget<String>(
        onAcceptWithDetails: (details) => add(details.data, node),
        builder: (context, candidates, rejected) => ColoredBox(
          color: candidates.isEmpty
              ? Colors.transparent
              : Theme.of(context).colorScheme.primaryContainer,
          child: children.isEmpty
              ? const SizedBox(
                  height: 60,
                  child: Center(child: Text('Drop components here')),
                )
              : Flex(
                  mainAxisSize: MainAxisSize.min,
                  direction: node.kind == 'row'
                      ? Axis.horizontal
                      : Axis.vertical,
                  crossAxisAlignment: switch (node.alignment) {
                    'center' => CrossAxisAlignment.center,
                    'end' => CrossAxisAlignment.end,
                    _ => CrossAxisAlignment.start,
                  },
                  children: children,
                ),
        ),
      );
    } else {
      final label = InbuiltComponents.getComponentMenuItems()
          .firstWhere((e) => e.key == node.kind)
          .name;
      body = SizedBox(
        height: 54,
        child: Center(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: () => setState(() => selected = node),
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight),
        padding: EdgeInsets.symmetric(
          horizontal: node.horizontalPadding,
          vertical: node.verticalPadding,
        ),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: active ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${node.kind.toUpperCase()} · ${node.percent.round()}%',
              style: const TextStyle(fontSize: 10),
            ),
            if (node.focusBar)
              FocusBar(
                color:
                    widget.theme?.styleColor ??
                    Theme.of(context).colorScheme.primary,
                child: body,
              )
            else
              body,
          ],
        ),
      ),
    );
  }

  Widget slider(
    String label,
    double value,
    double max,
    ValueChanged<double> change, {
    double min = 0,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$label: ${value.round()}'),
      Slider(
        value: value,
        min: min,
        max: max,
        onChanged: (v) => setState(() => change(v)),
      ),
    ],
  );
  Future<void> save() async {
    if (widget.theme?.documentSettingsController.isReadOnly == true) {
      setState(() => error = 'This document is read-only.');
      return;
    }
    if (name.text.trim().isEmpty || root.children.isEmpty) {
      setState(() => error = 'Enter a name and add at least one component.');
      return;
    }
    bool hasLeaf(CompositionNode n) => !n.isLayout || n.children.any(hasLeaf);
    bool emptyLayout(CompositionNode n) =>
        n.isLayout && (n.children.isEmpty || n.children.any(emptyLayout));
    if (!hasLeaf(root) || emptyLayout(root)) {
      setState(() => error = 'Add components to each empty wrapper.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final template = CompositionTemplate(
        widget.initialTemplate?.id ?? const Uuid().v4(),
        name.text.trim(),
        root,
        sourceDocumentId: widget.initialTemplate?.sourceDocumentId,
      );
      await CompositionLibrary.save(template);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = 'Could not save. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialTemplate == null
              ? 'Compose component'
              : 'Edit composed component',
        ),
        actions: [
          FilledButton(
            onPressed: saving ? null : save,
            child: Text(
              saving
                  ? 'Saving…'
                  : widget.initialTemplate == null
                  ? 'Save component'
                  : 'Save changes',
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: name,
              decoration: InputDecoration(
                labelText: 'Component name',
                hintText: 'e.g. Callout or Text + Image',
                errorText: error,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 210,
                  child: ListView(
                    children: [
                      const ListTile(title: Text('Wrappers')),
                      paletteItem(
                        'column',
                        'Column',
                        Icons.view_agenda_outlined,
                      ),
                      paletteItem('row', 'Row', Icons.view_column_outlined),
                      const Divider(),
                      const ListTile(title: Text('Inbuilt components')),
                      for (final def
                          in InbuiltComponents.getComponentMenuItems())
                        paletteItem(def.key, def.name, Icons.widgets_outlined),
                    ],
                  ),
                ),
                Expanded(
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Text(
                            'Drag from the palette, or select a wrapper and click an item.',
                          ),
                          const SizedBox(height: 16),
                          nodeView(root, minHeight: root.height),
                          const SizedBox(height: 24),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Live preview',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Try text, images, and focus here. Preview content is not saved.',
                            ),
                          ),
                          const SizedBox(height: 12),
                          CompositionPreview(
                            theme: widget.theme,
                            template: CompositionTemplate(
                              'preview',
                              name.text,
                              CompositionNode.fromJson(root.toJson()),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        selected.kind.toUpperCase(),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Width shares are normalized. Height shares set minimums; content can grow.',
                      ),
                      const SizedBox(height: 12),
                      if (selected != root)
                        slider(
                          'Width / minimum height share %',
                          selected.percent,
                          100,
                          (v) => selected.percent = v,
                          min: 1,
                        ),
                      slider(
                        'Horizontal padding',
                        selected.horizontalPadding,
                        64,
                        (v) => selected.horizontalPadding = v,
                      ),
                      slider(
                        'Vertical padding',
                        selected.verticalPadding,
                        64,
                        (v) => selected.verticalPadding = v,
                      ),
                      if (selected.isLayout) ...[
                        slider(
                          'Spacing',
                          selected.spacing,
                          64,
                          (v) => selected.spacing = v,
                        ),
                        DropdownButton<String>(
                          value: selected.alignment,
                          isExpanded: true,
                          items: ['start', 'center', 'end']
                              .map(
                                (v) => DropdownMenuItem(
                                  value: v,
                                  child: Text('Align $v'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => selected.alignment = v!),
                        ),
                      ],
                      if (selected == root)
                        slider(
                          'Minimum height',
                          root.height,
                          1200,
                          (v) => root.height = v,
                          min: 120,
                        ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Focus bar'),
                        value: selected.focusBar,
                        onChanged: (v) => setState(() => selected.focusBar = v),
                      ),
                      if (selected != root) ...[
                        Row(
                          children: [
                            for (final offset in [-1, 1])
                              IconButton(
                                tooltip: offset < 0
                                    ? 'Move earlier'
                                    : 'Move later',
                                icon: Icon(
                                  offset < 0
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward,
                                ),
                                onPressed: () => setState(() {
                                  void move(CompositionNode n) {
                                    final i = n.children.indexOf(selected);
                                    final j = i + offset;
                                    if (i >= 0 &&
                                        j >= 0 &&
                                        j < n.children.length) {
                                      final next = [...n.children];
                                      next.removeAt(i);
                                      next.insert(j, selected);
                                      n.children = next;
                                    } else {
                                      for (final c in n.children) {
                                        move(c);
                                      }
                                    }
                                  }

                                  move(root);
                                }),
                              ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: () => setState(() {
                            remove(root, selected);
                            selected = root;
                          }),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Remove'),
                        ),
                      ],
                    ],
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
