import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/heading_component.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/subheading_component.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/title_component.dart';
import 'package:flutter/material.dart';

/// Reads the current page on every opening, including unsaved rich text edits.
class TableOfContentsButton extends StatelessWidget {
  const TableOfContentsButton({
    super.key,
    required this.components,
    required this.onSelected,
  });

  final List<ComponentBox> Function() components;
  final ValueChanged<ComponentBox> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ComponentBox>(
      tooltip: 'Table of contents',
      icon: const Icon(Icons.toc),
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 360),
      onSelected: onSelected,
      itemBuilder: (context) {
        final items = <PopupMenuEntry<ComponentBox>>[
          const PopupMenuItem<ComponentBox>(
            enabled: false,
            child: Text('Table of contents'),
          ),
          const PopupMenuDivider(),
        ];
        final ancestors = <int>[];
        for (final box in components()) {
          final component = box.component;
          final level = switch (component) {
            TitleComponent() => 0,
            HeadingComponent() => 1,
            SubheadingComponent() => 2,
            _ => null,
          };
          if (level == null) continue;
          final state = component.state as TextComponentState;
          final text = state.controller.document.toPlainText().trim();
          if (text.isEmpty) continue;
          while (ancestors.isNotEmpty && ancestors.last >= level) {
            ancestors.removeLast();
          }
          items.add(
            PopupMenuItem<ComponentBox>(
              value: box,
              child: Padding(
                padding: EdgeInsets.only(left: ancestors.length * 20.0),
                child: Text(
                  text.replaceAll(RegExp(r'\s+'), ' '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: level == 0
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
          ancestors.add(level);
        }
        if (items.length == 2) {
          items.add(
            const PopupMenuItem<ComponentBox>(
              enabled: false,
              child: Text(
                'Add a title, heading, or subheading to see it here.',
              ),
            ),
          );
        }
        return items;
      },
    );
  }
}
