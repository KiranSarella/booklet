import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/ui/components/component_box.dart';

import 'composed_component.dart';
import 'composition.dart';

/// Scratch content is kept while adjusting a layout, and never saved as part
/// of the reusable template.
class CompositionPreview extends StatefulWidget {
  const CompositionPreview({super.key, required this.template, this.theme});
  final CompositionTemplate template;
  final PageSettingsController? theme;
  @override
  State<CompositionPreview> createState() => _CompositionPreviewState();
}

class _CompositionPreviewState extends State<CompositionPreview> {
  late final document = DocumentSettingsController();
  late final fallbackTheme = PageSettingsController(document);
  late final component = ComposedComponent(
    'composition-preview',
    widget.template,
  );
  late final box = ComponentBox(component: component);
  late String layout;

  @override
  void initState() {
    super.initState();
    layout = jsonEncode(widget.template.toJson());
  }

  @override
  void didUpdateWidget(covariant CompositionPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = jsonEncode(widget.template.toJson());
    if (next == layout) return;
    layout = next;
    component.state.updateLayout(widget.template, notify: false);
  }

  @override
  void dispose() {
    box.dispose();
    fallbackTheme.dispose();
    document.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme ?? fallbackTheme;
    return ListenableBuilder(
      listenable: theme,
      builder: (context, _) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.pageBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: box.buildUI(
          theme: theme,
          onSelect: () => setState(() => box.isSelected = true),
          onSelectRange: () => setState(() => box.isSelected = true),
          onCreateBelow: (_) {},
          onBackspaceAtStart: () {},
          onMoveToAdjacentTextComponent: (_) {},
          onPasteText: (_) async => false,
        ),
      ),
    );
  }
}
