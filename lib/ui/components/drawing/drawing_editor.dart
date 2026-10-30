import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'drawing_document.dart';

enum _Section { select, freehand, shapes, text }

typedef _Draft = ({List<DrawingElement> elements, Color background, Size size});

/// Changes remain local until Save commits the drawing and its image preview.
class DrawingEditor extends StatefulWidget {
  const DrawingEditor({super.key, required this.state});
  final DrawingComponentState state;
  @override
  State<DrawingEditor> createState() => _DrawingEditorState();
}

class _DrawingEditorState extends State<DrawingEditor> {
  late List<DrawingElement> _elements = List.of(widget.state.elements);
  late Size _canvasSize = widget.state.canvasSize;
  final _transform = TransformationController();
  Size _viewport = Size.zero;
  double _zoom = 1;
  bool _pan = false;
  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  late Color _background = widget.state.backgroundColor;
  final List<_Draft> _undo = [], _redo = [];
  List<Offset> _points = [];
  _Section _section = _Section.freehand;
  DrawingTool _tool = DrawingTool.pen;
  DrawingBrush _brush = DrawingBrush.pencil;
  Color _stroke = Colors.black, _fill = Colors.blue;
  double _width = 4, _fontSize = 36;
  String _font = 'sans-serif';
  bool _filled = false,
      _bold = false,
      _italic = false,
      _outlined = false,
      _shadow = false;
  bool _saving = false, _allowPop = false;
  int? _selected;
  Offset? _dragStart, _pointerDown;
  _Draft? _dragDraft;
  bool _resizing = false;
  bool get _dirty => _undo.isNotEmpty;
  DrawingElement? get _selection =>
      _selected == null ? null : _elements[_selected!];
  _Draft get _draft => (
    elements: List.of(_elements),
    background: _background,
    size: _canvasSize,
  );
  DrawingElement _element(
    List<Offset> points, {
    String text = '',
  }) => DrawingElement(
    tool: _tool,
    points: points,
    color: _stroke,
    fillColor: _fill,
    width: [DrawingTool.pen, DrawingTool.line, DrawingTool.text].contains(_tool)
        ? _width.clamp(1, 30)
        : _width,
    text: text,
    fontSize: _fontSize,
    fontFamily: _font,
    bold: _bold,
    italic: _italic,
    outlined: _outlined,
    shadow: _shadow,
    filled: _filled,
    brush: _brush,
  );
  void _commit(
    List<DrawingElement> elements, {
    Color? background,
    Size? size,
  }) => setState(() {
    _undo.add(_draft);
    _redo.clear();
    _elements = elements;
    _background = background ?? _background;
    _canvasSize = size ?? _canvasSize;
  });
  void _restore(_Draft draft) {
    _elements = List.of(draft.elements);
    _background = draft.background;
    _canvasSize = draft.size;
    _selected = null;
  }

  void _undoAction() => setState(() {
    _redo.add(_draft);
    _restore(_undo.removeLast());
  });
  void _redoAction() => setState(() {
    _undo.add(_draft);
    _restore(_redo.removeLast());
  });
  Offset _position(Offset point, Size size) => Offset(
    (point.dx / size.width * _canvasSize.width).clamp(0, _canvasSize.width),
    (point.dy / size.height * _canvasSize.height).clamp(0, _canvasSize.height),
  );
  void _select(int? index) {
    _selected = index;
    if (index == null) return;
    final e = _elements[index];
    _stroke = e.color;
    _fill = e.fillColor;
    _width = e.width;
    _fontSize = e.fontSize;
    _font = e.fontFamily;
    _brush = e.brush;
    _filled = e.filled;
    _bold = e.bold;
    _italic = e.italic;
    _outlined = e.outlined;
    _shadow = e.shadow;
  }

  int? _hit(Offset point, double tolerance) {
    for (var i = _elements.length - 1; i >= 0; i--) {
      if (_elements[i].hitTest(point, tolerance)) return i;
    }
    return null;
  }

  void _style(VoidCallback change) {
    setState(change);
    final e = _selection;
    if (e == null) return;
    final updated = List.of(_elements);
    updated[_selected!] = e.copyWith(
      color: _stroke,
      fillColor: _fill,
      width: _width,
      fontSize: _fontSize,
      fontFamily: _font,
      brush: _brush,
      filled: _filled,
      bold: _bold,
      italic: _italic,
      outlined: _outlined,
      shadow: _shadow,
    );
    _commit(updated);
  }

  void _delete() {
    final index = _selected;
    if (index == null) return;
    _selected = null;
    _commit(List.of(_elements)..removeAt(index));
  }

  void _start(Offset p, double tolerance) {
    if (_section == _Section.select) {
      final e = _selection;
      _resizing =
          e != null &&
          (p - e.bounds.inflate(8).bottomRight).distance < tolerance * 2;
      if (!_resizing) _select(_hit(p, tolerance));
      _dragStart = p;
      _dragDraft = _draft;
    } else if (_tool != DrawingTool.text) {
      _points = [p];
    }
    setState(() {});
  }

  void _update(Offset p) {
    setState(() {
      if (_section == _Section.select) {
        if (_selected == null || _dragDraft == null || _dragStart == null) {
          return;
        }
        final original = _dragDraft!.elements[_selected!];
        final delta = p - _dragStart!;
        final bounds = original.bounds;
        var sx = bounds.width < 1
            ? 1.0
            : ((bounds.width + delta.dx) / bounds.width).clamp(.05, 20.0);
        final sy = bounds.height < 1
            ? 1.0
            : ((bounds.height + delta.dy) / bounds.height).clamp(.05, 20.0);
        if (original.tool == DrawingTool.circle) sx = sy;
        _elements = List.of(_elements);
        _elements[_selected!] = _resizing
            ? original.resized(sx, sy)
            : original.translated(delta);
      } else if (_points.isNotEmpty) {
        if (_tool == DrawingTool.circle) {
          final delta = p - _points.first;
          final side = delta.dx.abs() > delta.dy.abs()
              ? delta.dx.abs()
              : delta.dy.abs();
          p =
              _points.first +
              Offset(
                side * (delta.dx < 0 ? -1 : 1),
                side * (delta.dy < 0 ? -1 : 1),
              );
        }
        _points = _tool == DrawingTool.pen
            ? [..._points, p]
            : [_points.first, p];
      }
    });
  }

  void _end() {
    if (_section == _Section.select) {
      if (_selected != null &&
          _dragDraft != null &&
          _elements[_selected!] != _dragDraft!.elements[_selected!]) {
        _undo.add(_dragDraft!);
        _redo.clear();
        _select(_selected);
      }
      _dragStart = null;
      _dragDraft = null;
    } else if (_points.isNotEmpty) {
      _commit([..._elements, _element(_points)]);
    }
    setState(() => _points = []);
  }

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
      final preview = await DrawingPainter.render(
        _elements,
        backgroundColor: _background,
        canvasSize: _canvasSize,
      );
      if (!mounted) return;
      widget.state.save(
        _elements,
        preview,
        backgroundColor: _background,
        canvasSize: _canvasSize,
      );
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

  Future<void> _text(Offset point, {int? index}) async {
    final original = index == null ? null : _elements[index];
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _TextDialog(initial: original?.text ?? ''),
    );
    if (value == null || value.trim().isEmpty || !mounted) return;
    if (index == null) {
      _commit([
        ..._elements,
        _element([point], text: value),
      ]);
    } else {
      final updated = List.of(_elements);
      updated[index] = original!.copyWith(text: value);
      _commit(updated);
    }
  }

  Future<void> _color(
    String label,
    Color initial,
    ValueChanged<Color> apply,
  ) async {
    var color = initial;
    final result = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: initial,
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
    if (result != null && mounted) apply(result);
  }

  Widget _colorButton(String label, Color color, ValueChanged<Color> apply) =>
      TextButton.icon(
        onPressed: () => _color(label, color, apply),
        icon: Icon(
          Icons.circle,
          color: color,
          shadows: const [Shadow(color: Colors.grey, blurRadius: 2)],
        ),
        label: Text(label),
      );
  Widget _toggle(String label, bool value, ValueChanged<bool> apply) =>
      FilterChip(
        label: Text(label),
        selected: value,
        onSelected: (v) => _style(() => apply(v)),
      );
  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> apply,
  ) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('$label ${value.round()}'),
      SizedBox(
        width: 120,
        child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: (v) => _style(() => apply(v)),
        ),
      ),
    ],
  );
  void _changeSection(_Section section) => setState(() {
    _section = section;
    _selected = null;
    _points = [];
    _tool = switch (section) {
      _Section.text => DrawingTool.text,
      _Section.shapes => DrawingTool.rectangle,
      _ => DrawingTool.pen,
    };
  });
  Widget _toolbar() {
    final e = _selection;
    final text = e?.tool == DrawingTool.text || (_section == _Section.text);
    final pen = e?.tool == DrawingTool.pen || (_section == _Section.freehand);
    final shape = e != null
        ? ![
            DrawingTool.pen,
            DrawingTool.text,
            DrawingTool.line,
          ].contains(e.tool)
        : _section == _Section.shapes && _tool != DrawingTool.line;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (final section in _Section.values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 12,
                      ),
                      backgroundColor: _section == section
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                    ),
                    onPressed: () => _changeSection(section),
                    child: Text(switch (section) {
                      _Section.select => 'Select',
                      _Section.freehand => 'Freehand',
                      _Section.shapes => 'Shapes',
                      _Section.text => 'Text',
                    }),
                  ),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (_section == _Section.shapes)
                for (final tool in [
                  DrawingTool.line,
                  DrawingTool.rectangle,
                  DrawingTool.ellipse,
                  DrawingTool.circle,
                ])
                  ChoiceChip(
                    label: Text(
                      tool.name[0].toUpperCase() + tool.name.substring(1),
                    ),
                    selected: _tool == tool,
                    onSelected: (_) => setState(() => _tool = tool),
                  ),
              if (pen)
                DropdownButton<DrawingBrush>(
                  value: _brush,
                  items: [
                    for (final brush in DrawingBrush.values)
                      DropdownMenuItem(
                        value: brush,
                        child: Text(
                          brush.name[0].toUpperCase() + brush.name.substring(1),
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) _style(() => _brush = v);
                  },
                ),
              if (_section != _Section.select || e != null) ...[
                _colorButton(
                  'Stroke',
                  _stroke,
                  (v) => _style(() => _stroke = v),
                ),
                if (shape || text)
                  _colorButton(
                    'Fill color',
                    _fill,
                    (v) => _style(() => _fill = v),
                  ),
                if (!text || _outlined)
                  _slider(
                    'Width',
                    _width,
                    shape ? 0 : 1,
                    30,
                    (v) => _width = v,
                  ),
                if (shape) _toggle('Fill', _filled, (v) => _filled = v),
                if (text) ...[
                  DropdownButton<String>(
                    value: _font,
                    items: const [
                      DropdownMenuItem(
                        value: 'sans-serif',
                        child: Text('Classic'),
                      ),
                      DropdownMenuItem(
                        value: 'serif',
                        child: Text(
                          'Serif',
                          style: TextStyle(fontFamily: 'serif'),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'ComicNeue',
                        child: Text(
                          'Comic',
                          style: TextStyle(fontFamily: 'ComicNeue'),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Bangers',
                        child: Text(
                          'Poster',
                          style: TextStyle(fontFamily: 'Bangers'),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'CourierPrime',
                        child: Text(
                          'Typewriter',
                          style: TextStyle(fontFamily: 'CourierPrime'),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Pacifico',
                        child: Text(
                          'Script',
                          style: TextStyle(fontFamily: 'Pacifico'),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) _style(() => _font = v);
                    },
                  ),
                  _slider('Size', _fontSize, 8, 200, (v) => _fontSize = v),
                  _toggle('Bold', _bold, (v) => _bold = v),
                  _toggle('Italic', _italic, (v) => _italic = v),
                  _toggle('Outline', _outlined, (v) => _outlined = v),
                  _toggle('Shadow', _shadow, (v) => _shadow = v),
                ],
              ],
              if (e != null) ...[
                if (text)
                  TextButton.icon(
                    onPressed: () => _text(e.points.first, index: _selected),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit text'),
                  ),
                IconButton(
                  onPressed: _delete,
                  tooltip: 'Delete selected',
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  double _fitScale(Size viewport) => math
      .min(
        (viewport.width - 32).clamp(1, double.infinity) / _canvasSize.width,
        (viewport.height - 32).clamp(1, double.infinity) / _canvasSize.height,
      )
      .clamp(.02, 8);

  void _setZoom(double value, {Size? viewport}) {
    final area = viewport ?? _viewport;
    final zoom = value.clamp(.02, 8.0);
    setState(() {
      _zoom = zoom;
      _transform.value = Matrix4.identity()
        ..setEntry(0, 0, zoom)
        ..setEntry(1, 1, zoom)
        ..setEntry(0, 3, (area.width - _canvasSize.width * zoom) / 2)
        ..setEntry(1, 3, (area.height - _canvasSize.height * zoom) / 2);
    });
  }

  Size? _lastCanvasSize, _lastWindowSize;
  Future<void> _chooseCanvasSize() async {
    final size = await showDialog<Size>(
      context: context,
      builder: (_) => _CanvasSizeDialog(initial: _canvasSize),
    );
    if (size != null && mounted && _elements.isEmpty && size != _canvasSize) {
      _commit(List.of(_elements), size: size);
    }
  }

  Widget _canvas() => LayoutBuilder(
    builder: (context, constraints) {
      final viewport = constraints.biggest;
      _viewport = viewport;
      final windowSize = MediaQuery.sizeOf(context);
      if ((_lastCanvasSize != _canvasSize || _lastWindowSize != windowSize) &&
          _dragDraft == null) {
        _lastCanvasSize = _canvasSize;
        _lastWindowSize = windowSize;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _setZoom(_fitScale(_viewport));
        });
      }
      final size = _canvasSize;
      final tolerance = 10 / _zoom;
      return Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: Colors.grey.shade300,
              child: Builder(
                builder: (context) {
                  return InteractiveViewer(
                    transformationController: _transform,
                    constrained: false,
                    minScale: .02,
                    maxScale: 8,
                    boundaryMargin: const EdgeInsets.all(10000),
                    panEnabled: _pan,
                    scaleEnabled: _pan,
                    onInteractionUpdate: (_) => setState(
                      () => _zoom = _transform.value.getMaxScaleOnAxis(),
                    ),
                    child: SizedBox.fromSize(
                      size: _canvasSize,
                      child: IgnorePointer(
                        ignoring: _pan,
                        child: ClipRect(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapUp: (d) {
                              final p = _position(d.localPosition, size);
                              if (_section == _Section.select) {
                                setState(() => _select(_hit(p, tolerance)));
                              } else if (_tool == DrawingTool.text) {
                                _text(p);
                              } else if (_tool == DrawingTool.pen) {
                                _commit([
                                  ..._elements,
                                  _element([p]),
                                ]);
                              }
                            },
                            onDoubleTap: _selection?.tool == DrawingTool.text
                                ? () => _text(
                                    _selection!.points.first,
                                    index: _selected,
                                  )
                                : null,
                            onPanDown: (d) =>
                                _pointerDown = _position(d.localPosition, size),
                            onPanStart: (d) {
                              _start(
                                _pointerDown ??
                                    _position(d.localPosition, size),
                                tolerance,
                              );
                              _update(_position(d.localPosition, size));
                            },
                            onPanUpdate: (d) =>
                                _update(_position(d.localPosition, size)),
                            onPanEnd: (_) => _end(),
                            onPanCancel: () => setState(() {
                              if (_dragDraft != null) _restore(_dragDraft!);
                              _dragDraft = null;
                              _points = [];
                            }),
                            child: CustomPaint(
                              size: size,
                              painter: DrawingPainter(
                                [
                                  ..._elements,
                                  if (_points.isNotEmpty) _element(_points),
                                ],
                                backgroundColor: _background,
                                selectedIndex: _selected,
                                documentSize: _canvasSize,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (_elements.isEmpty)
            Positioned(
              top: 8,
              left: 8,
              child: FilledButton.tonalIcon(
                onPressed: _chooseCanvasSize,
                icon: const Icon(Icons.aspect_ratio),
                label: const Text('Canvas size'),
              ),
            ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => setState(() => _pan = !_pan),
                    tooltip: 'Pan canvas',
                    isSelected: _pan,
                    icon: const Icon(Icons.pan_tool_outlined),
                  ),
                  IconButton(
                    onPressed: _zoom <= .02
                        ? null
                        : () => _setZoom(_zoom / 1.25),
                    tooltip: 'Zoom out',
                    icon: const Icon(Icons.remove),
                  ),
                  Text('${(_zoom * 100).round()}%'),
                  IconButton(
                    onPressed: _zoom >= 8 ? null : () => _setZoom(_zoom * 1.25),
                    tooltip: 'Zoom in',
                    icon: const Icon(Icons.add),
                  ),
                  IconButton(
                    onPressed: () => _setZoom(1),
                    tooltip: 'Actual size',
                    icon: const Icon(Icons.looks_one_outlined),
                  ),
                  IconButton(
                    onPressed: () => _setZoom(_fitScale(_viewport)),
                    tooltip: 'Fit canvas',
                    icon: const Icon(Icons.fit_screen),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _close();
    },
    child: Scaffold(
      appBar: AppBar(
        title: MediaQuery.sizeOf(context).width < 600
            ? null
            : const Text('Drawing'),
        leading: IconButton(
          onPressed: _saving ? null : _close,
          tooltip: 'Close drawing',
          icon: const Icon(Icons.close),
        ),
        actions: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: _saving || _undo.isEmpty ? null : _undoAction,
            tooltip: 'Undo',
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: _saving || _redo.isEmpty ? null : _redoAction,
            tooltip: 'Redo',
            icon: const Icon(Icons.redo),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: _saving || _elements.isEmpty
                ? null
                : () {
                    _selected = null;
                    _commit([]);
                  },
            tooltip: 'Clear',
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: _saving
                ? null
                : () => _color(
                    'Background',
                    _background,
                    (v) => _commit(List.of(_elements), background: v),
                  ),
            tooltip: 'Background',
            icon: Icon(
              Icons.format_color_fill,
              color: _background.computeLuminance() > .9 ? null : _background,
            ),
          ),
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
        ],
      ),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _saving,
          child: LayoutBuilder(
            builder: (context, outer) => Column(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: outer.maxHeight * .35),
                  child: Material(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    child: SingleChildScrollView(child: _toolbar()),
                  ),
                ),
                Expanded(child: _canvas()),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(switch (_section) {
                    _Section.select => 'Select an object, drag to move, or drag its blue corner to resize.',
                    _Section.text => 'Tap the canvas to add text. Use Select to edit existing text.',
                    _ => 'Drag on the canvas to draw. Save to update the page preview.',
                  }, textAlign: TextAlign.center),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _TextDialog extends StatefulWidget {
  const _TextDialog({required this.initial});
  final String initial;
  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initial.isEmpty ? 'Add text' : 'Edit text'),
    content: TextField(
      controller: _controller,
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
        onPressed: () => Navigator.pop(context, _controller.text),
        child: Text(widget.initial.isEmpty ? 'Add' : 'Update'),
      ),
    ],
  );
}

class _CanvasSizeDialog extends StatefulWidget {
  const _CanvasSizeDialog({required this.initial});
  final Size initial;
  @override
  State<_CanvasSizeDialog> createState() => _CanvasSizeDialogState();
}

class _CanvasSizeDialogState extends State<_CanvasSizeDialog> {
  final _form = GlobalKey<FormState>();
  late final _width = TextEditingController(
    text: widget.initial.width.toInt().toString(),
  );
  late final _height = TextEditingController(
    text: widget.initial.height.toInt().toString(),
  );
  @override
  void dispose() {
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final number = int.tryParse(value ?? '');
    return number == null || number < 64 || number > 4096
        ? 'Enter 64–4096 pixels'
        : null;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Canvas size'),
    content: SizedBox(
      width: 360,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  for (final preset in const [
                    Size(800, 600),
                    Size(1200, 800),
                    Size(1024, 1024),
                    Size(800, 1200),
                  ])
                    ActionChip(
                      label: Text(
                        '${preset.width.toInt()} × ${preset.height.toInt()}',
                      ),
                      onPressed: () {
                        _width.text = preset.width.toInt().toString();
                        _height.text = preset.height.toInt().toString();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _width,
                keyboardType: TextInputType.number,
                validator: _validate,
                decoration: const InputDecoration(labelText: 'Width (px)'),
              ),
              TextFormField(
                controller: _height,
                keyboardType: TextInputType.number,
                validator: _validate,
                decoration: const InputDecoration(labelText: 'Height (px)'),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(
              context,
              Size(double.parse(_width.text), double.parse(_height.text)),
            );
          }
        },
        child: const Text('Apply'),
      ),
    ],
  );
}
