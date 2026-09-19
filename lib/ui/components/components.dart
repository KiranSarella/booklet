import 'package:flutter/material.dart';
import 'package:booklet/ui/_helpers/autoheight_richtext.dart';
import 'package:booklet/ui/components/component_visual_state.dart';
import 'package:booklet/ui/components/component_types.dart';
import 'package:booklet/ui/editor_themes/editor_themes.dart';
import 'package:flutter_quill/flutter_quill.dart';

abstract class Component {
  // String get id;
  String get name;
  Attribute<dynamic> get alignment => Attribute.leftAlignment;
  Widget createUI({
    required ComponentVisualState component,
    required bool isSelected,
    required VoidCallback onSelect,
    required VoidCallback onCreateBelow,
  });
  static final Map<String, Component Function(EditorTheme)> _factories =
      {
        'title': (theme) => TitleComponent(theme),
        'heading': (theme) => Heading1Component(theme),
        // 'Heading 2': (theme) => Heading2Component(theme),
        'subheading': (theme) => Subheading1Component(theme),
        // 'Subheading 2': (theme) => Subheading2Component(theme),
        'inline_heading': (theme) => Subheading3Component(theme),
        'subtitle': (theme) => SubtitleComponent(theme),
        'label': (theme) => LabelComponent(theme),
        'text': (theme) => TextComponent(theme),
        'dashed_list': (theme) => DashedListComponent(theme),
        'numbered_list': (theme) => NumberedListComponent(theme),
        'checklist': (theme) => ChecklistComponent(theme),
        'focus': (theme) => FocusComponent(theme),
        'block_text': (theme) => BlockTextComponent(theme),
        'location': (theme) => LocationComponent(theme),
        'caption': (theme) => CaptionComponent(theme),
        'footnote': (theme) => FootnoteComponent(theme),
      };

  static Component fromType(String type, EditorTheme theme) {
    final factory =
        _factories[type] ?? _factories[ComponentTypes.getIdForTitle(type)];
    if (factory == null) {
      throw ArgumentError.value(type, 'type', 'Unknown component type');
    }
    return factory(theme);
  }
}

abstract class RichTextComponentRenderer implements Component {
  RichTextComponentRenderer(this.name, this.theme);

  double fontSizePercent(double percent) => theme.baseFontSize * percent / 100;

  @override
  final String name;
  final EditorTheme theme;
  TextStyle get textStyle;
  @override
  Attribute<dynamic> get alignment => Attribute.leftAlignment;

  @override
  Widget createUI({
    required ComponentVisualState component,
    required bool isSelected,
    required VoidCallback onSelect,
    required VoidCallback onCreateBelow,
  }) {
    return AutoHeightRichText2(
      visualState: component,
      isSelected: isSelected,
      onSelect: onSelect,
      onCreateBelow: onCreateBelow,
      textStyle: textStyle,
      alignment: alignment,
      editorPadding: editorPadding,
      placeholder: name,
    );
  }

  EdgeInsets get editorPadding =>
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
}

class TitleComponent extends RichTextComponentRenderer {
  TitleComponent(EditorTheme theme) : super('Title', theme);

  @override
  TextStyle get textStyle => TextStyle(
    fontSize: fontSizePercent(271),
    fontWeight: FontWeight.w800,
    color: theme.titleColor,
    height: 1.4,
  );

  @override
  Attribute<dynamic> get alignment => Attribute.centerAlignment;
}

class Heading1Component extends RichTextComponentRenderer {
  Heading1Component(EditorTheme theme) : super('Heading', theme);

  @override
  TextStyle get textStyle => TextStyle(
    fontSize: fontSizePercent(214),
    fontWeight: FontWeight.w800,
    color: theme.headingColor,
  );
}

class Heading2Component extends RichTextComponentRenderer {
  Heading2Component(EditorTheme theme) : super('Heading 2', theme);

  @override
  TextStyle get textStyle => TextStyle(
    fontSize: fontSizePercent(171),
    fontWeight: FontWeight.w800,
    color: theme.headingColor,
  );
}

class HeadingComponent extends Heading2Component {
  HeadingComponent(super.theme);
}

class Subheading1Component extends RichTextComponentRenderer {
  Subheading1Component(EditorTheme theme) : super('Subheading', theme);

  @override
  TextStyle get textStyle => TextStyle(
    fontSize: fontSizePercent(157),
    fontWeight: FontWeight.w700,
    color: theme.subheadingColor,
  );
}

class Subheading2Component extends RichTextComponentRenderer {
  Subheading2Component(EditorTheme theme) : super('Subheading 2', theme);

  @override
  TextStyle get textStyle => TextStyle(
    fontSize: fontSizePercent(129),
    fontWeight: FontWeight.w700,
    color: theme.subheadingColor,
  );
}

class Subheading3Component extends RichTextComponentRenderer {
  Subheading3Component(EditorTheme theme) : super('Inline Heading', theme);

  @override
  TextStyle get textStyle => TextStyle(
    fontSize: fontSizePercent(114),
    fontWeight: FontWeight.w700,
    color: theme.subheadingColor,
  );
}

class SubtitleComponent extends RichTextComponentRenderer {
  SubtitleComponent(EditorTheme theme) : super('Subtitle', theme);

  @override
  TextStyle get textStyle => TextStyle(
    fontSize: fontSizePercent(157),
    height: 1.2,
    color: theme.textColor,
    fontStyle: .italic,
    fontWeight: .w200,
    letterSpacing: 0.2,
  );

  @override
  Attribute<dynamic> get alignment => Attribute.centerAlignment;
}

class LabelComponent extends RichTextComponentRenderer {
  LabelComponent(EditorTheme theme) : super('Label', theme);

  @override
  TextStyle get textStyle => TextStyle(
    fontSize: fontSizePercent(107),
    fontWeight: FontWeight.w600,
    color: theme.textColor,
  );
}

class TextComponent extends RichTextComponentRenderer {
  TextComponent(EditorTheme theme) : super('Text', theme);

  @override
  TextStyle get textStyle => TextStyle(
    fontSize: fontSizePercent(100),
    fontWeight: FontWeight.w300,
    color: theme.textColor,
    height: 1.5,
  );
}

class DashedListComponent extends RichTextComponentRenderer {
  DashedListComponent(EditorTheme theme) : super('- Dashed List', theme);

  @override
  TextStyle get textStyle =>
      TextStyle(fontSize: fontSizePercent(100), color: theme.textColor);
}

class NumberedListComponent extends RichTextComponentRenderer {
  NumberedListComponent(EditorTheme theme) : super('1. Numbered List', theme);

  @override
  TextStyle get textStyle =>
      TextStyle(fontSize: fontSizePercent(100), color: theme.textColor);
}

class ChecklistComponent extends RichTextComponentRenderer {
  ChecklistComponent(EditorTheme theme) : super('🗸 Checklist', theme);

  @override
  TextStyle get textStyle =>
      TextStyle(fontSize: fontSizePercent(100), color: theme.textColor);
}

class FocusComponent extends RichTextComponentRenderer {
  FocusComponent(EditorTheme theme) : super('|  Focus', theme);

  @override
  TextStyle get textStyle => TextStyle(
    fontSize: fontSizePercent(100),
    fontWeight: FontWeight.w500,
    color: theme.textColor,
  );
}

class BlockTextComponent extends RichTextComponentRenderer {
  BlockTextComponent(EditorTheme theme) : super('Block Text', theme);

  @override
  EdgeInsets get editorPadding =>
      const EdgeInsets.symmetric(horizontal: 40, vertical: 12);

  @override
  TextStyle get textStyle => TextStyle(
    fontFamily: 'Menlo',
    letterSpacing: 1.2,
    color: theme.textColor,
    height: 1.5,
  );
}

class LocationComponent extends RichTextComponentRenderer {
  LocationComponent(EditorTheme theme) : super('📍 Location', theme);

  @override
  TextStyle get textStyle => TextStyle(
    fontSize: fontSizePercent(100),
    fontWeight: FontWeight.w500,
    color: theme.textColor,
  );
}

class CaptionComponent extends RichTextComponentRenderer {
  CaptionComponent(EditorTheme theme) : super('Caption', theme);

  @override
  TextStyle get textStyle => TextStyle(
    fontSize: fontSizePercent(86),
    fontWeight: FontWeight.w300,
    color: theme.textColor,
  );
}

class FootnoteComponent extends RichTextComponentRenderer {
  FootnoteComponent(EditorTheme theme) : super('Footnote', theme);

  @override
  TextStyle get textStyle => TextStyle(
    fontSize: fontSizePercent(79),
    fontWeight: FontWeight.w200,
    color: theme.textColor,
  );
}

class ComponentBox {
  ComponentBox({required this.componentInfo, List<dynamic>? delta})
    : component = ComponentVisualState(
        componentInfo.renderer.alignment,
        delta: delta,
      );

  final ComponentInfo componentInfo;
  final ComponentVisualState component;
  final GlobalKey componentKey = GlobalKey();
  bool isSelected = false;

  Widget createUI({
    required VoidCallback onSelect,
    required VoidCallback onCreateBelow,
  }) {
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.indigo : Colors.transparent,
            width: isSelected ? 1.8 : 0,
          ),
        ),
        child: componentInfo.renderer.createUI(
          component: component,
          isSelected: isSelected,
          onSelect: onSelect,
          onCreateBelow: onCreateBelow,
        ),
      ),
    );
  }

  void dispose() {
    component.dispose();
  }
}

class ComponentInfo {
  ComponentInfo({required this.renderer});
  Component renderer;
}
