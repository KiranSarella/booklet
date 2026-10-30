import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'drawing_document.dart';

/// A draft is local to this route; only Save updates the component.
class DrawingEditor extends StatefulWidget {
  const DrawingEditor({super.key, required this.state});
  final DrawingComponentState state;
  @override
  State<DrawingEditor> createState() => _DrawingEditorState();
}

class _DrawingEditorState extends State<DrawingEditor> {
  late List<DrawingElement> _elements = List.of(widget.state.elements);
  final List<List<DrawingElement>> _undo = [], _redo = [];
  List<Offset> _points = [];
  DrawingTool _tool = DrawingTool.pen;
  Color _color = Colors.black;
  double _width = 4, _fontSize = 36;
  bool _filled = false, _bold = false, _italic = false, _outlined = false;
  bool _saving = false, _allowPop = false;
  bool get _dirty => _undo.isNotEmpty;

  DrawingElement _element(List<Offset> points, {String text = ''}) =>
      DrawingElement(
        tool: _tool,
        points: points,
        color: _color,
        width: _width,
        text: text,
        fontSize: _fontSize,
        bold: _bold,
        italic: _italic,
        outlined: _outlined,
        filled: _filled,
      );
  void _commit(List<DrawingElement> elements) => setState(() {
    _undo.add(List.of(_elements));
    _redo.clear();
    _elements = elements;
  });
  void _undoAction() => setState(() {
    _redo.add(List.of(_elements));
    _elements = _undo.removeLast();
  });
  void _redoAction() => setState(() {
    _undo.add(List.of(_elements));
    _elements = _redo.removeLast();
  });
  Offset _position(Offset point, Size size) => Offset(
    (point.dx / size.width * 1200).clamp(0, 1200),
    (point.dy / size.height * 800).clamp(0, 800),
  );
  Future<void> _close() async {
    if (_saving) return;
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard drawing changes?'),
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
      if (discard != true || !mounted) return;
    }
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final preview = await DrawingPainter.render(_elements);
      if (!mounted) return;
      widget.state.save(_elements, preview);
      setState(() {
        _allowPop = true;
        _saving = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save drawing. Please try again.'),
        ),
      );
    }
  }

  Future<void> _addText(Offset point) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add text'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 1,
          maxLines: 5,
          decoration: const InputDecoration(hintText: 'Enter text'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    // The dialog's exit animation may still be using its controller.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (text != null && text.trim().isNotEmpty && mounted) {
      _commit([
        ..._elements,
        _element([point], text: text),
      ]);
    }
  }

  Future<void> _chooseColor() async {
    var color = _color;
    final result = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Drawing color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: color,
            onColorChanged: (value) => color = value,
            enableAlpha: false,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, color),
            child: const Text('Use color'),
          ),
        ],
      ),
    );
    if (result != null && mounted) setState(() => _color = result);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _close();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _saving ? null : _close,
          tooltip: 'Close drawing',
          icon: const Icon(Icons.close),
        ),
        title: const Text('Drawing'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: const Text('Save'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _saving,
          child: Column(
            children: [
              Material(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final tool in DrawingTool.values)
                          Tooltip(
                            message: tool.name,
                            child: ChoiceChip(
                              label: Text(switch (tool) {
                                DrawingTool.pen => 'Freehand',
                                DrawingTool.line => 'Line',
                                DrawingTool.rectangle => 'Rectangle',
                                DrawingTool.ellipse => 'Ellipse',
                                DrawingTool.text => 'Text',
                              }),
                              selected: _tool == tool,
                              onSelected: (_) => setState(() {
                                _tool = tool;
                                _points = [];
                              }),
                            ),
                          ),
                        IconButton(
                          onPressed: _chooseColor,
                          tooltip: 'Color',
                          icon: Icon(Icons.palette, color: _color),
                        ),
                        if (_tool != DrawingTool.text) ...[
                          const Text('Width'),
                          SizedBox(
                            width: 110,
                            child: Slider(
                              value: _width,
                              min: 1,
                              max: 30,
                              label: _width.round().toString(),
                              onChanged: (v) => setState(() => _width = v),
                            ),
                          ),
                          if (_tool == DrawingTool.rectangle ||
                              _tool == DrawingTool.ellipse)
                            FilterChip(
                              label: const Text('Fill'),
                              selected: _filled,
                              onSelected: (v) => setState(() => _filled = v),
                            ),
                        ] else ...[
                          const Text('Size'),
                          SizedBox(
                            width: 110,
                            child: Slider(
                              value: _fontSize,
                              min: 12,
                              max: 120,
                              label: _fontSize.round().toString(),
                              onChanged: (v) => setState(() => _fontSize = v),
                            ),
                          ),
                          FilterChip(
                            label: const Text('Bold'),
                            selected: _bold,
                            onSelected: (v) => setState(() => _bold = v),
                          ),
                          FilterChip(
                            label: const Text('Italic'),
                            selected: _italic,
                            onSelected: (v) => setState(() => _italic = v),
                          ),
                          FilterChip(
                            label: const Text('Outline'),
                            selected: _outlined,
                            onSelected: (v) => setState(() => _outlined = v),
                          ),
                        ],
                        IconButton(
                          onPressed: _undo.isEmpty ? null : _undoAction,
                          tooltip: 'Undo',
                          icon: const Icon(Icons.undo),
                        ),
                        IconButton(
                          onPressed: _redo.isEmpty ? null : _redoAction,
                          tooltip: 'Redo',
                          icon: const Icon(Icons.redo),
                        ),
                        TextButton(
                          onPressed: _elements.isEmpty
                              ? null
                              : () => _commit([]),
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  color: Colors.grey.shade300,
                  padding: const EdgeInsets.all(12),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1.5,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final size = constraints.biggest;
                          return ClipRect(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapUp: (details) {
                                final p = _position(
                                  details.localPosition,
                                  size,
                                );
                                if (_tool == DrawingTool.text) {
                                  _addText(p);
                                } else if (_tool == DrawingTool.pen) {
                                  _commit([
                                    ..._elements,
                                    _element([p]),
                                  ]);
                                }
                              },
                              onPanStart: _tool == DrawingTool.text
                                  ? null
                                  : (details) => setState(() {
                                      _points = [
                                        _position(details.localPosition, size),
                                      ];
                                    }),
                              onPanUpdate: _tool == DrawingTool.text
                                  ? null
                                  : (details) => setState(() {
                                      final p = _position(
                                        details.localPosition,
                                        size,
                                      );
                                      _points = _tool == DrawingTool.pen
                                          ? [..._points, p]
                                          : [_points.first, p];
                                    }),
                              onPanEnd: _tool == DrawingTool.text
                                  ? null
                                  : (_) {
                                      if (_points.isNotEmpty) {
                                        _commit([
                                          ..._elements,
                                          _element(_points),
                                        ]);
                                        setState(() => _points = []);
                                      }
                                    },
                              onPanCancel: () => setState(() => _points = []),
                              child: CustomPaint(
                                size: size,
                                painter: DrawingPainter([
                                  ..._elements,
                                  if (_points.isNotEmpty) _element(_points),
                                ]),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  _tool == DrawingTool.text
                      ? 'Tap the canvas to place text. Choose size and style before adding.'
                      : 'Drag on the canvas to draw. Save to update the page preview.',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
