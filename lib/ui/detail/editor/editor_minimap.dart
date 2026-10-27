import 'dart:async';

import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/detail/editor/component_minimap_preview.dart';
import 'package:flutter/material.dart';

/// A lightweight outline of the rendered page, without mounting editors twice.
class EditorMinimap extends StatefulWidget {
  const EditorMinimap({
    super.key,
    required this.components,
    required this.scrollController,
    required this.viewportKey,
    required this.onNavigate,
  });

  final List<ComponentBox> components;
  final ScrollController scrollController;
  final GlobalKey viewportKey;
  final ValueChanged<ComponentBox> onNavigate;

  @override
  State<EditorMinimap> createState() => _EditorMinimapState();
}

class _EditorMinimapState extends State<EditorMinimap> {
  List<Rect> _bounds = [];
  double _extent = 1;
  bool _measurementScheduled = false;
  final List<StreamSubscription<dynamic>> _textSubscriptions = [];

  @override
  void initState() {
    super.initState();
    _listenToText();
  }

  @override
  void didUpdateWidget(EditorMinimap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _listenToText();
  }

  void _listenToText() {
    for (final subscription in _textSubscriptions) {
      unawaited(subscription.cancel());
    }
    _textSubscriptions.clear();
    for (final box in widget.components) {
      final state = box.component.state;
      if (state is TextComponentState) {
        _textSubscriptions.add(
          state.controller.document.changes.listen((_) {
            if (mounted) setState(() {});
          }),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final subscription in _textSubscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }

  void _scheduleMeasurement() {
    if (_measurementScheduled) return;
    _measurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurementScheduled = false;
      if (!mounted || !widget.scrollController.hasClients) return;
      final viewport = widget.viewportKey.currentContext?.findRenderObject();
      if (viewport is! RenderBox || !viewport.hasSize) return;
      final position = widget.scrollController.position;
      final origin = viewport.localToGlobal(Offset.zero).dy;
      final bounds = widget.components.map((box) {
        final render = box.componentKey.currentContext?.findRenderObject();
        if (render is! RenderBox || !render.hasSize) return Rect.zero;
        return Rect.fromLTWH(
          0,
          render.localToGlobal(Offset.zero).dy - origin + position.pixels,
          1,
          render.size.height,
        );
      }).toList();
      final extent = position.maxScrollExtent + position.viewportDimension;
      if (extent != _extent ||
          bounds.length != _bounds.length ||
          bounds.indexed.any((entry) => entry.$2 != _bounds[entry.$1])) {
        setState(() {
          _bounds = bounds;
          _extent = extent > 0 ? extent : 1;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.scrollController,
        ...widget.components.map((box) => box.component.state),
      ]),
      builder: (context, _) {
        _scheduleMeasurement();
        final colors = Theme.of(context).colorScheme;
        final position = widget.scrollController.hasClients
            ? widget.scrollController.position
            : null;
        return Material(
          elevation: 4,
          shadowColor: colors.shadow.withValues(alpha: 0.15),
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                // child: Row(
                //   children: [
                //     Icon(Icons.map_outlined, size: 16, color: colors.primary),
                //     const SizedBox(width: 8),
                //     Text(
                //       'Minimap',
                //       style: Theme.of(context).textTheme.labelMedium,
                //     ),
                //   ],
                // ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                  child: widget.components.isEmpty
                      ? const Center(child: Text('No components'))
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final scale = constraints.maxHeight / _extent;
                            void scrub(Offset offset) {
                              if (position == null) return;
                              widget.scrollController.jumpTo(
                                (offset.dy / scale -
                                        position.viewportDimension / 2)
                                    .clamp(
                                      position.minScrollExtent,
                                      position.maxScrollExtent,
                                    ),
                              );
                            }

                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapDown: (event) => scrub(event.localPosition),
                              onVerticalDragUpdate: (event) =>
                                  scrub(event.localPosition),
                              child: Stack(
                                clipBehavior: Clip.hardEdge,
                                children: [
                                  Positioned.fill(
                                    child: ColoredBox(color: colors.surface),
                                  ),
                                  for (
                                    var i = 0;
                                    i < widget.components.length &&
                                        i < _bounds.length;
                                    i++
                                  )
                                    if (_bounds[i] != Rect.zero)
                                      Positioned(
                                        top: _bounds[i].top * scale,
                                        height: (_bounds[i].height * scale)
                                            .clamp(3.0, constraints.maxHeight),
                                        left: 6,
                                        right: 6,
                                        child: _MinimapBlock(
                                          box: widget.components[i],
                                          onTap: () => widget.onNavigate(
                                            widget.components[i],
                                          ),
                                        ),
                                      ),
                                  if (position != null)
                                    Positioned(
                                      top:
                                          position.pixels.clamp(0, _extent) *
                                          scale,
                                      height:
                                          position.viewportDimension * scale,
                                      left: 0,
                                      right: 0,
                                      child: IgnorePointer(
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: colors.primary.withValues(
                                              alpha: 0.08,
                                            ),
                                            border: Border.all(
                                              color: colors.primary.withValues(
                                                alpha: 0.55,
                                              ),
                                              width: 1.5,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MinimapBlock extends StatelessWidget {
  const _MinimapBlock({required this.box, required this.onTap});
  final ComponentBox box;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final state = box.component.state;
    final name = box.component.def.name;
    final text = state is TextComponentState
        ? state.controller.document.toPlainText().trim()
        : '';
    return Semantics(
      label: 'Scroll to ${text.isEmpty ? name : text}',
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ComponentMinimapPreview(box: box),
      ),
    );
  }
}
