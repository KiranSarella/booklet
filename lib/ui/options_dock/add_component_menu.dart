import 'package:flutter/material.dart';
import 'package:booklet/ui/components/inbuilt_components.dart';

class AddComponentMenu extends StatelessWidget {
  const AddComponentMenu({
    super.key,
    required this.title,
    required this.onSelected,
  });

  static const double baseFontSize = 14;
  static const double _menuHeight = 480;

  final String title;
  final ValueChanged<String> onSelected;

  List<String> get componentTypes => _componentTypes;

  static final List<String> _componentTypes = InbuiltComponents
      .getComponentMenuItems()
      .map((definition) => definition.key)
      .toList(growable: false);

  static String titleforkey(String key) {
    return InbuiltComponents.getComponentMenuItems()
        .firstWhere((definition) => definition.key == key)
        .name;
  }

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
                    fontSize: baseFontSize,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ...componentTypes.map(
                (componentKey) => InkWell(
                  onTap: () => onSelected(componentKey),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    child: Text(
                      titleforkey(componentKey),
                      style: _styleForComponent(titleforkey(componentKey)),
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
          fontWeight: FontWeight.w800,
        );
      case 'Heading':
        return const TextStyle(
          fontSize: baseFontSize * 1.75,
          fontWeight: FontWeight.w800,
        );
      case 'Heading 2':
        return const TextStyle(
          fontSize: baseFontSize * 1.55,
          fontWeight: FontWeight.w800,
        );
      case 'Subheading':
        return const TextStyle(
          fontSize: baseFontSize * 1.35,
          fontWeight: FontWeight.w700,
        );
      case 'Subheading 2':
        return const TextStyle(
          fontSize: baseFontSize * 1.25,
          fontWeight: FontWeight.w700,
        );
      case 'Inline Heading':
        return const TextStyle(
          fontSize: baseFontSize * 1.15,
          fontWeight: FontWeight.w700,
        );
      case 'Subtitle':
        return const TextStyle(
          fontSize: baseFontSize * 1.35, 
          height: 1
          );
      case 'Label':
        return const TextStyle(
          fontFamily: 'Menlo',
          fontSize: baseFontSize * 1.1,
          // fontWeight: FontWeight.w600,
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
