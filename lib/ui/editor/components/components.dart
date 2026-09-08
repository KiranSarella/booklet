import 'package:flutter/material.dart';
import 'package:booklet/ui/helpers_ui/autoheight_richtext.dart';
import 'package:booklet/ui/editor/components/booklet_component.dart';

abstract class ComponentRenderer {
  String get name;
  Widget createUI({
    required BookletComponent component,
    required bool isSelected,
    required VoidCallback onSelect,
    required VoidCallback onCreateBelow,
  });
  static final Map<String, ComponentRenderer Function()> _factories = {
    'Title': TitleComponent.new,
    'Heading 1': Heading1Component.new,
    'Heading 2': Heading2Component.new,
    'Subheading 1': Subheading1Component.new,
    'Subheading 2': Subheading2Component.new,
    'Subheading 3': Subheading3Component.new,
    'Subtitle': SubtitleComponent.new,
    'Label': LabelComponent.new,
    'Text': TextComponent.new,
    '- Dashed List': DashedListComponent.new,
    '1. Numbered List': NumberedListComponent.new,
    '🗸 Checklist': ChecklistComponent.new,
    '|  Focus': FocusComponent.new,
    'Block Text': BlockTextComponent.new,
    '📍 Location': LocationComponent.new,
    'Caption': CaptionComponent.new,
    'Footnote': FootnoteComponent.new,
  };

  static ComponentRenderer fromType(String type) {
    final factory = _factories[type];
    if (factory == null) {
      throw ArgumentError.value(type, 'type', 'Unknown component type');
    }
    return factory();
  }
}

abstract class RichTextComponentRenderer implements ComponentRenderer {
  const RichTextComponentRenderer(this.name, this.textStyle);

  @override
  final String name;
  final TextStyle textStyle;

  @override
  Widget createUI({
    required BookletComponent component,
    required bool isSelected,
    required VoidCallback onSelect,
    required VoidCallback onCreateBelow,
  }) {
    return AutoHeightRichText2(
      component: component,
      isSelected: isSelected,
      onSelect: onSelect,
      onCreateBelow: onCreateBelow,
      textStyle: textStyle,
    );
  }
}

class TitleComponent extends RichTextComponentRenderer {
  const TitleComponent()
    : super(
        'Title',
        const TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w800,
          color: Color.fromARGB(255, 14, 0, 0),
          height: 1.4,
        ),
      );
}

class Heading1Component extends RichTextComponentRenderer {
  const Heading1Component()
    : super(
        'Heading 1',
        const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: Color.fromARGB(255, 8, 28, 254),
        ),
      );
}

class Heading2Component extends RichTextComponentRenderer {
  const Heading2Component()
    : super(
        'Heading 2',
        const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Color.fromARGB(255, 8, 28, 254),
        ),
      );
}

class HeadingComponent extends Heading2Component {
  const HeadingComponent();
}

class Subheading1Component extends RichTextComponentRenderer {
  const Subheading1Component()
    : super(
        'Subheading 1',
        const TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: Color.fromARGB(255, 5, 224, 177),
        ),
      );
}

class Subheading2Component extends RichTextComponentRenderer {
  const Subheading2Component()
    : super(
        'Subheading 2',
        const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Color.fromARGB(255, 252, 219, 4),
        ),
      );
}

class Subheading3Component extends RichTextComponentRenderer {
  const Subheading3Component()
    : super(
        'Subheading 3',
        const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color.fromARGB(255, 248, 128, 16),
        ),
      );
}

class SubtitleComponent extends RichTextComponentRenderer {
  const SubtitleComponent()
    : super(
        'Subtitle',
        const TextStyle(
          fontSize: 22, 
          height: 1.2, 
          color: Color.fromARGB(255, 155, 55, 134),
          fontStyle: .italic,
          fontWeight: .w500
          ),
      );
}

class LabelComponent extends RichTextComponentRenderer {
  const LabelComponent()
    : super(
        'Label',
        const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF364152),
        ),
      );
}

class TextComponent extends RichTextComponentRenderer {
  const TextComponent()
    : super(
        'Text',
        const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w300,
          color: Color.fromARGB(255, 0, 8, 0),
        ),
      );
}

class DashedListComponent extends RichTextComponentRenderer {
  const DashedListComponent()
    : super(
        '- Dashed List',
        const TextStyle(fontSize: 14, color: Color(0xFF334E68)),
      );
}

class NumberedListComponent extends RichTextComponentRenderer {
  const NumberedListComponent()
    : super(
        '1. Numbered List',
        const TextStyle(fontSize: 14, color: Color(0xFF334E68)),
      );
}

class ChecklistComponent extends RichTextComponentRenderer {
  const ChecklistComponent()
    : super(
        '🗸 Checklist',
        const TextStyle(fontSize: 14, color: Color(0xFF2F6B4F)),
      );
}

class FocusComponent extends RichTextComponentRenderer {
  const FocusComponent()
    : super(
        '|  Focus',
        const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.indigo,
        ),
      );
}

class BlockTextComponent extends RichTextComponentRenderer {
  const BlockTextComponent()
    : super(
        'Block Text',
        const TextStyle(
          fontFamily: 'Menlo',
          letterSpacing: 1.2,
          height: 0.9,
          color: Color(0xFF263238),
        ),
      );
}

class LocationComponent extends RichTextComponentRenderer {
  const LocationComponent()
    : super(
        '📍 Location',
        const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.blue,
        ),
      );
}

class CaptionComponent extends RichTextComponentRenderer {
  const CaptionComponent()
    : super(
        'Caption',
        const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w300,
          color: Color(0xFF627D98),
        ),
      );
}

class FootnoteComponent extends RichTextComponentRenderer {
  const FootnoteComponent()
    : super(
        'Footnote',
        const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w200,
          color: Color(0xFF829AB1),
        ),
      );
}

class ComponentBox {
  ComponentBox({required this.componentInfo}) : component = BookletComponent();

  final ComponentInfo componentInfo;
  final BookletComponent component;
  final GlobalKey componentKey = GlobalKey();

  Widget createUI({
    required bool isSelected,
    required VoidCallback onSelect,
    required VoidCallback onCreateBelow,
  }) {
    return componentInfo.renderer.createUI(
      component: component,
      isSelected: isSelected,
      onSelect: onSelect,
      onCreateBelow: onCreateBelow,
    );
  }

  void dispose() {
    component.dispose();
  }
}

class ComponentInfo {
  const ComponentInfo({required this.renderer});
  final ComponentRenderer renderer;
}
