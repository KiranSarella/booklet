import 'package:flutter/material.dart';
import 'package:booklet/ui/helpers_ui/autoheight_richtext.dart';
import 'package:booklet/ui/editor/components/booklet_component.dart';
import 'package:booklet/ui/editor/editor_themes/editor_themes.dart';

abstract class ComponentRenderer {
  String get name;
  Widget createUI({
    required BookletComponent component,
    required bool isSelected,
    required VoidCallback onSelect,
    required VoidCallback onCreateBelow,
  });
  static final Map<String, ComponentRenderer Function(EditorTheme)> _factories =
      {
        'Title': (theme) => TitleComponent(theme),
        'Heading 1': (theme) => Heading1Component(theme),
        'Heading 2': (theme) => Heading2Component(theme),
        'Subheading 1': (theme) => Subheading1Component(theme),
        'Subheading 2': (theme) => Subheading2Component(theme),
        'Subheading 3': (theme) => Subheading3Component(theme),
        'Subtitle': (theme) => SubtitleComponent(theme),
        'Label': (theme) => LabelComponent(theme),
        'Text': (theme) => TextComponent(theme),
        '- Dashed List': (theme) => DashedListComponent(theme),
        '1. Numbered List': (theme) => NumberedListComponent(theme),
        '🗸 Checklist': (theme) => ChecklistComponent(theme),
        '|  Focus': (theme) => FocusComponent(theme),
        'Block Text': (theme) => BlockTextComponent(theme),
        '📍 Location': (theme) => LocationComponent(theme),
        'Caption': (theme) => CaptionComponent(theme),
        'Footnote': (theme) => FootnoteComponent(theme),
      };

  static ComponentRenderer fromType(String type, EditorTheme theme) {
    final factory = _factories[type];
    if (factory == null) {
      throw ArgumentError.value(type, 'type', 'Unknown component type');
    }
    return factory(theme);
  }
}

abstract class RichTextComponentRenderer implements ComponentRenderer {
  RichTextComponentRenderer(this.name, this.theme);

  @override
  final String name;
  final EditorTheme theme;
  TextStyle get textStyle;

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
  TitleComponent(EditorTheme theme) : super('Title', theme);

  @override
  TextStyle get textStyle => TextStyle(
    fontSize: 38,
    fontWeight: FontWeight.w800,
    color: theme.titleColor,
    height: 1.4,
  );
}

class Heading1Component extends RichTextComponentRenderer {
  Heading1Component(EditorTheme theme) : super('Heading 1', theme);

  @override
  TextStyle get textStyle => TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: theme.heading1Color,
  );
}

class Heading2Component extends RichTextComponentRenderer {
  Heading2Component(EditorTheme theme) : super('Heading 2', theme);

  @override
  TextStyle get textStyle => TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: theme.heading2Color,
  );
}

class HeadingComponent extends Heading2Component {
  HeadingComponent(super.theme);
}

class Subheading1Component extends RichTextComponentRenderer {
  Subheading1Component(EditorTheme theme) : super('Subheading 1', theme);

  @override
  TextStyle get textStyle => TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w700,
    color: theme.subheading1Color,
  );
}

class Subheading2Component extends RichTextComponentRenderer {
  Subheading2Component(EditorTheme theme) : super('Subheading 2', theme);

  @override
  TextStyle get textStyle => TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: theme.subheading2Color,
  );
}

class Subheading3Component extends RichTextComponentRenderer {
  Subheading3Component(EditorTheme theme) : super('Subheading 3', theme);

  @override
  TextStyle get textStyle => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: theme.subheading3Color,
  );
}

class SubtitleComponent extends RichTextComponentRenderer {
  SubtitleComponent(EditorTheme theme) : super('Subtitle', theme);

  @override
  TextStyle get textStyle => TextStyle(
    fontSize: 22,
    height: 1.2,
    color: theme.textColor,
    fontStyle: .italic,
    fontWeight: .w500,
  );
}

class LabelComponent extends RichTextComponentRenderer {
  LabelComponent(EditorTheme theme) : super('Label', theme);

  @override
  TextStyle get textStyle => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: theme.textColor,
  );
}

class TextComponent extends RichTextComponentRenderer {
  TextComponent(EditorTheme theme) : super('Text', theme);

  @override
  TextStyle get textStyle => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w300,
    color: theme.textColor,
  );
}

class DashedListComponent extends RichTextComponentRenderer {
  DashedListComponent(EditorTheme theme) : super('- Dashed List', theme);

  @override
  TextStyle get textStyle => TextStyle(fontSize: 14, color: theme.textColor);
}

class NumberedListComponent extends RichTextComponentRenderer {
  NumberedListComponent(EditorTheme theme) : super('1. Numbered List', theme);

  @override
  TextStyle get textStyle => TextStyle(fontSize: 14, color: theme.textColor);
}

class ChecklistComponent extends RichTextComponentRenderer {
  ChecklistComponent(EditorTheme theme) : super('🗸 Checklist', theme);

  @override
  TextStyle get textStyle => TextStyle(fontSize: 14, color: theme.textColor);
}

class FocusComponent extends RichTextComponentRenderer {
  FocusComponent(EditorTheme theme) : super('|  Focus', theme);

  @override
  TextStyle get textStyle => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: theme.textColor,
  );
}

class BlockTextComponent extends RichTextComponentRenderer {
  BlockTextComponent(EditorTheme theme) : super('Block Text', theme);

  @override
  TextStyle get textStyle => TextStyle(
    fontFamily: 'Menlo',
    letterSpacing: 1.2,
    height: 0.9,
    color: theme.textColor,
  );
}

class LocationComponent extends RichTextComponentRenderer {
  LocationComponent(EditorTheme theme) : super('📍 Location', theme);

  @override
  TextStyle get textStyle => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: theme.textColor,
  );
}

class CaptionComponent extends RichTextComponentRenderer {
  CaptionComponent(EditorTheme theme) : super('Caption', theme);

  @override
  TextStyle get textStyle => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w300,
    color: theme.textColor,
  );
}

class FootnoteComponent extends RichTextComponentRenderer {
  FootnoteComponent(EditorTheme theme) : super('Footnote', theme);

  @override
  TextStyle get textStyle => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w200,
    color: theme.textColor,
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
