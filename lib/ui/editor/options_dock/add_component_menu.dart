import 'package:flutter/material.dart';

class AddComponentMenu extends StatelessWidget {
  const AddComponentMenu({
    super.key,
    required this.title,
    required this.onSelected,
  });

  static const double baseFontSize = 14;
  static const double _menuHeight = 480;

  final String title;
  final List<String> componentTypes = _componentTypes;
  final ValueChanged<String> onSelected;

  static const _componentTypes = [
    'Title',
    'Heading 1',
    'Heading 2',
    'Subheading 1',
    'Subheading 2',
    'Subheading 3',
    'Subtitle',
    'Label',
    'Text',
    '- Dashed List',
    '1. Numbered List',
    '🗸 Checklist',
    '|  Focus',
    'Block Text',
    '📍 Location',
    'Caption',
    'Footnote',
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(14),
      color: Colors.white,
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
                    fontSize: baseFontSize,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              ...componentTypes.map(
                (component) => InkWell(
                  onTap: () => onSelected(component),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    child: Text(
                      component,
                      style: _styleForComponent(component),
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

  TextStyle _styleForComponent(String component) {
    switch (component) {
      case 'Title':
        return const TextStyle(
          fontSize: baseFontSize * 2.2, 
          height: 1.2,
          fontWeight: FontWeight.w800
        );
      case 'Heading 1':
        return const TextStyle(
          fontSize: baseFontSize * 1.75,
          fontWeight: FontWeight.w800,
        );
      case 'Heading 2':
        return const TextStyle(
          fontSize: baseFontSize * 1.55,
          fontWeight: FontWeight.w800,
        );
      case 'Subheading 1':
        return const TextStyle(
          fontSize: baseFontSize * 1.35,
          fontWeight: FontWeight.w700,
        );
      case 'Subheading 2':
        return const TextStyle(
          fontSize: baseFontSize * 1.25,
          fontWeight: FontWeight.w700,
        );
      case 'Subheading 3':
        return const TextStyle(
          fontSize: baseFontSize * 1.15,
          fontWeight: FontWeight.w700,
        );
      case 'Subtitle':
        return const TextStyle(fontSize: baseFontSize * 1.55, height: 1);
      case 'Label':
        return const TextStyle(
          fontSize: baseFontSize * 1.1,
          fontWeight: FontWeight.w600,
        );
      case 'Caption':
        return const TextStyle(
          fontSize: baseFontSize * 0.9,
          fontWeight: FontWeight.w300,
        );
      case 'Footnote':
        return const TextStyle(
          fontSize: baseFontSize * 0.8,
          fontWeight: FontWeight.w200,
        );
      case 'Block Text':
        return const TextStyle(
          fontFamily: 'Menlo',
          letterSpacing: 1.2,
          height: 0.9,
        );
      default:
        return const TextStyle(fontSize: baseFontSize);
    }
  }
}
