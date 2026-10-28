import 'dart:async';
import 'dart:math' as math;

import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/detail/editor/component_minimap_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

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
  double? _dragWindowOffset;
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
                            // Preserve readable rows instead of squeezing the
                            // whole document into the available height.
                            final miniatureBounds = <Rect>[];
                            var documentBottom = 0.0;
                            var miniatureBottom = 0.0;
                            for (
                              var i = 0;
                              i < _bounds.length &&
                                  i < widget.components.length;
                              i++
                            ) {
                              final bounds = _bounds[i];
                              if (bounds == Rect.zero) {
                                miniatureBounds.add(Rect.zero);
                                continue;
                              }
                              final heading =
                                  [
                                    'title',
                                    'heading',
                                    'subheading',
                                    'inline_heading',
                                  ].contains(
                                    widget.components[i].component.def.key,
                                  );
                              final top =
                                  miniatureBottom +
                                  math.max(0.0, bounds.top - documentBottom) *
                                      0.25;
                              final height = math.max(
                                heading ? 22.0 : 6.0,
                                bounds.height * 0.25,
                              );
                              miniatureBounds.add(
                                Rect.fromLTWH(0, top, 1, height),
                              );
                              documentBottom = bounds.bottom;
                              miniatureBottom = top + height;
                            }
                            final miniatureExtent =
                                miniatureBottom +
                                math.max(0.0, _extent - documentBottom) * 0.25;

                            // Translate between document and minimap coordinates,
                            // including rows expanded to keep headings readable.
                            double translate(
                              double value, {
                              bool inverse = false,
                            }) {
                              var sourceBottom = 0.0;
                              var targetBottom = 0.0;
                              for (var i = 0; i < miniatureBounds.length; i++) {
                                if (_bounds[i] == Rect.zero) continue;
                                final source = inverse
                                    ? miniatureBounds[i]
                                    : _bounds[i];
                                final target = inverse
                                    ? _bounds[i]
                                    : miniatureBounds[i];
                                if (value < source.top) {
                                  final gap = source.top - sourceBottom;
                                  return targetBottom +
                                      (gap > 0
                                          ? (value - sourceBottom) /
                                                gap *
                                                (target.top - targetBottom)
                                          : 0);
                                }
                                if (value <= source.bottom) {
                                  return target.top +
                                      (value - source.top) /
                                          math.max(source.height, 0.001) *
                                          target.height;
                                }
                                sourceBottom = source.bottom;
                                targetBottom = target.bottom;
                              }
                              return targetBottom +
                                  (value - sourceBottom) * (inverse ? 4 : 0.25);
                            }

                            final viewportTop = translate(
                              position?.pixels ?? 0,
                            );
                            final viewportBottom = translate(
                              (position?.pixels ?? 0) +
                                  (position?.viewportDimension ?? _extent),
                            );
                            final overflow = math.max(
                              0.0,
                              miniatureExtent - constraints.maxHeight,
                            );
                            final progress =
                                position == null ||
                                    position.maxScrollExtent <= 0
                                ? 0.0
                                : (position.pixels / position.maxScrollExtent)
                                      .clamp(0.0, 1.0);
                            final windowOffset = overflow * progress;
                            void scrub(Offset offset) {
                              if (position == null) return;
                              final documentOffset = translate(
                                offset.dy + (_dragWindowOffset ?? windowOffset),
                                inverse: true,
                              );
                              widget.scrollController.jumpTo(
                                (documentOffset -
                                        position.viewportDimension / 2)
                                    .clamp(
                                      position.minScrollExtent,
                                      position.maxScrollExtent,
                                    ),
                              );
                            }

                            return Listener(
                              onPointerSignal: (event) {
                                if (event is PointerScrollEvent &&
                                    position != null) {
                                  GestureBinding.instance.pointerSignalResolver
                                      .register(
                                        event,
                                        (_) => widget.scrollController.jumpTo(
                                          (position.pixels +
                                                  event.scrollDelta.dy * 4)
                                              .clamp(
                                                position.minScrollExtent,
                                                position.maxScrollExtent,
                                              ),
                                        ),
                                      );
                                }
                              },
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapDown: (event) =>
                                    scrub(event.localPosition),
                                onVerticalDragStart: (_) =>
                                    _dragWindowOffset = windowOffset,
                                onVerticalDragEnd: (_) =>
                                    _dragWindowOffset = null,
                                onVerticalDragCancel: () =>
                                    _dragWindowOffset = null,
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
                                          top:
                                              miniatureBounds[i].top -
                                              windowOffset,
                                          height: miniatureBounds[i].height,
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
                                        top: viewportTop - windowOffset,
                                        height: viewportBottom - viewportTop,
                                        left: 0,
                                        right: 0,
                                        child: IgnorePointer(
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: colors.primary.withValues(
                                                alpha: 0.08,
                                              ),
                                              border: Border.all(
                                                color: colors.primary
                                                    .withValues(alpha: 0.55),
                                                width: 1.5,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
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
