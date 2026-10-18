import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/business/components_business/component_def.dart';
import 'package:booklet/business/components_business/inbuilt_components/inbuit_components_definations.dart';
import 'package:booklet/ui/_helpers/autoheight_richtext.dart';
import 'package:booklet/ui/components/component.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class SubheadingComponent with TextComponentStateOwner implements Component {
  SubheadingComponent({required this.id});

  @override
  final String id;

  @override
  ComponentDef get def => SubheadingComponentDef();

  @override
  Widget buildUI({
    required PageSettingsController theme,
    required ComponentState componentState,
    required bool isSelected,
    required VoidCallback onSelect,
    required VoidCallback onCreateBelow,
  }) {
    double fontSizePercent(double percent) =>
        theme.baseFontSize * percent / 100;

    TextStyle textStyle = TextStyle(
      fontSize: fontSizePercent(157),
      fontWeight: FontWeight.w700,
      color: theme.headingColor,
    );

    return AutoHeightRichText2(
      visualState: componentState,
      isSelected: isSelected,
      onSelect: onSelect,
      onCreateBelow: onCreateBelow,
      textStyle: textStyle,
      alignment: alignment,
      editorPadding: editorPadding,
      placeholder: def.name,
    );
  }

  @override
  Attribute<dynamic> get alignment => Attribute.leftAlignment;

  EdgeInsets get editorPadding =>
      // const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
      const EdgeInsets.fromLTRB(14, 30, 14, 12);
}
