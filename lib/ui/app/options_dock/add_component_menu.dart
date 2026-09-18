import 'package:flutter/material.dart';
import 'package:booklet/ui/app/components/component_types.dart';

class AddComponentMenu extends StatelessWidget {
  const AddComponentMenu({
    super.key,
    required this.title,
    required this.onSelected,
  });

  static const double _baseFontSize = 14;
  static const double _menuHeight = 480;

  final String title;
  final ValueChanged<String> onSelected;

  static const _componentTypes = [
    'title',
    'heading',
    'subheading',
    'inline_heading',
    'subtitle',
    'label',
    'text',
    'dashed_list',
    'numbered_list',
    'checklist',
    'focus',
    'block_text',
    'location',
    'caption',
    'footnote',
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(14),
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        width: 220,
        height: _menuHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: _baseFontSize,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ..._componentTypes.map(
                (type) => InkWell(
                  onTap: () => onSelected(type),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    child: Text(
                      ComponentTypes.getTitleFor(type),
                      style: ComponentTypes.styleForComponent(type),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
