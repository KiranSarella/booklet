import 'dart:ffi';

import 'package:booklet/business/components_business/component_def.dart';
import 'package:booklet/ui/components/component.dart';
import 'package:flutter/material.dart';
import 'package:booklet/ui/_helpers/autoheight_richtext.dart';
import 'package:booklet/ui/components/component_visual_state.dart';
import 'package:booklet/ui/components/component_types.dart';
import 'package:booklet/ui/editor_themes/editor_themes.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:booklet/business/components_business/inbuilt_components/inbuit_components_definations.dart';


class TitleComponent implements Component {

  TitleComponent({required String id});

  @override
  String id = "";

  @override
  ComponentDef get def => TitleComponentDef();

  @override
  Widget buildUI({
    required EditorTheme theme, 
    required ComponentVisualState componentState, 
    required bool isSelected, 
    required VoidCallback onSelect, 
    required VoidCallback onCreateBelow
    }) {

    double fontSizePercent(double percent) => theme.baseFontSize * percent / 100;

    TextStyle textStyle = TextStyle(
      fontSize: fontSizePercent(290),
      fontWeight: FontWeight.w800,
      color: theme.titleColor,
      height: 1.4,
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

  Attribute<dynamic> get alignment => Attribute.leftAlignment;

  EdgeInsets get editorPadding =>
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
}


class HeadingComponent implements Component {

  HeadingComponent({required String id});

  @override
  String id = "";

  @override
  ComponentDef get def => HeadingComponentDef();

  @override
  Widget buildUI({
    required EditorTheme theme, 
    required ComponentVisualState componentState, 
    required bool isSelected, 
    required VoidCallback onSelect, 
    required VoidCallback onCreateBelow
    }) {

    double fontSizePercent(double percent) => theme.baseFontSize * percent / 100;

    TextStyle textStyle = TextStyle(
      fontSize: fontSizePercent(214),
      fontWeight: FontWeight.w800,
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

  Attribute<dynamic> get alignment => Attribute.leftAlignment;

  EdgeInsets get editorPadding =>
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
}



class SubheadingComponent implements Component {

  SubheadingComponent({required String id});

  @override
  String id = "";

  @override
  ComponentDef get def => SubheadingComponentDef();

  @override
  Widget buildUI({
    required EditorTheme theme, 
    required ComponentVisualState componentState, 
    required bool isSelected, 
    required VoidCallback onSelect, 
    required VoidCallback onCreateBelow
    }) {

    double fontSizePercent(double percent) => theme.baseFontSize * percent / 100;

    TextStyle textStyle = TextStyle(
      fontSize: fontSizePercent(157),
      fontWeight: FontWeight.w700,
      color: theme.subheadingColor,
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

  Attribute<dynamic> get alignment => Attribute.leftAlignment;

  EdgeInsets get editorPadding =>
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
}




class InlineHeadingComponent implements Component {

  InlineHeadingComponent({required String id});

  @override
  String id = "";

  @override
  ComponentDef get def => InlineHeadingComponentDef();

  @override
  Widget buildUI({
    required EditorTheme theme, 
    required ComponentVisualState componentState, 
    required bool isSelected, 
    required VoidCallback onSelect, 
    required VoidCallback onCreateBelow
    }) {

    double fontSizePercent(double percent) => theme.baseFontSize * percent / 100;

    TextStyle textStyle = TextStyle(
      fontSize: fontSizePercent(117),
      fontWeight: FontWeight.w600,
      color: theme.subheadingColor,
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

  Attribute<dynamic> get alignment => Attribute.leftAlignment;

  EdgeInsets get editorPadding =>
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
}



class SubtitleComponent implements Component {

  SubtitleComponent({required String id});

  @override
  String id = "";

  @override
  ComponentDef get def => SubtitleComponentDef();

  @override
  Widget buildUI({
    required EditorTheme theme, 
    required ComponentVisualState componentState, 
    required bool isSelected, 
    required VoidCallback onSelect, 
    required VoidCallback onCreateBelow
    }) {

    double fontSizePercent(double percent) => theme.baseFontSize * percent / 100;

    TextStyle textStyle = TextStyle(
      fontSize: fontSizePercent(157),
      height: 1.2,
      color: theme.textColor,
      fontStyle: .italic,
      fontWeight: .w200,
      letterSpacing: 0.2,
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

  Attribute<dynamic> get alignment => Attribute.centerAlignment;

  EdgeInsets get editorPadding =>
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
}



class LabelComponent implements Component {

  LabelComponent({required String id});

  @override
  String id = "";

  @override
  ComponentDef get def => LabelComponentDef();

  @override
  Widget buildUI({
    required EditorTheme theme, 
    required ComponentVisualState componentState, 
    required bool isSelected, 
    required VoidCallback onSelect, 
    required VoidCallback onCreateBelow
    }) {

    double fontSizePercent(double percent) => theme.baseFontSize * percent / 100;

    TextStyle textStyle = TextStyle(
      fontSize: fontSizePercent(107),
      fontWeight: FontWeight.w600,
      color: theme.textColor,
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

  Attribute<dynamic> get alignment => Attribute.centerAlignment;

  EdgeInsets get editorPadding =>
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
}


class TextComponent implements Component {

  TextComponent({required String id});

  @override
  String id = "";

  @override
  ComponentDef get def => TextComponentDef();

  @override
  Widget buildUI({
    required EditorTheme theme, 
    required ComponentVisualState componentState, 
    required bool isSelected, 
    required VoidCallback onSelect, 
    required VoidCallback onCreateBelow
    }) {

    double fontSizePercent(double percent) => theme.baseFontSize * percent / 100;

    TextStyle textStyle = TextStyle(
      fontSize: fontSizePercent(100),
      fontWeight: FontWeight.w300,
      color: theme.textColor,
      height: 1.5,
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

  Attribute<dynamic> get alignment => Attribute.centerAlignment;

  EdgeInsets get editorPadding =>
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
}


class DashedListComponent implements Component {

  DashedListComponent({required String id});

  @override
  String id = "";

  @override
  ComponentDef get def => DashedListComponentDef();

  @override
  Widget buildUI({
    required EditorTheme theme, 
    required ComponentVisualState componentState, 
    required bool isSelected, 
    required VoidCallback onSelect, 
    required VoidCallback onCreateBelow
    }) {

    double fontSizePercent(double percent) => theme.baseFontSize * percent / 100;

    TextStyle textStyle = TextStyle(
      fontSize: fontSizePercent(100),
      fontWeight: FontWeight.w300,
      color: theme.textColor,
      height: 1.5,
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

  Attribute<dynamic> get alignment => Attribute.centerAlignment;

  EdgeInsets get editorPadding =>
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
}



class NumberedListComponent implements Component {

  NumberedListComponent({required String id});

  @override
  String id = "";

  @override
  ComponentDef get def => NumberedListComponentDef();

  @override
  Widget buildUI({
    required EditorTheme theme, 
    required ComponentVisualState componentState, 
    required bool isSelected, 
    required VoidCallback onSelect, 
    required VoidCallback onCreateBelow
    }) {

    double fontSizePercent(double percent) => theme.baseFontSize * percent / 100;

    TextStyle textStyle = TextStyle(
      fontSize: fontSizePercent(100),
      fontWeight: FontWeight.w300,
      color: theme.textColor,
      height: 1.5,
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

  Attribute<dynamic> get alignment => Attribute.centerAlignment;

  EdgeInsets get editorPadding =>
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
}



class ChecklistComponent implements Component {

  ChecklistComponent({required String id});

  @override
  String id = "";

  @override
  ComponentDef get def => ChecklistComponentDef();

  @override
  Widget buildUI({
    required EditorTheme theme, 
    required ComponentVisualState componentState, 
    required bool isSelected, 
    required VoidCallback onSelect, 
    required VoidCallback onCreateBelow
    }) {

    double fontSizePercent(double percent) => theme.baseFontSize * percent / 100;

    TextStyle textStyle = TextStyle(
      fontSize: fontSizePercent(100),
      fontWeight: FontWeight.w300,
      color: theme.textColor,
      height: 1.5,
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

  Attribute<dynamic> get alignment => Attribute.centerAlignment;

  EdgeInsets get editorPadding =>
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
}



class FocusComponent implements Component {

  FocusComponent({required String id});

  @override
  String id = "";

  @override
  ComponentDef get def => FocusComponentDef();

  @override
  Widget buildUI({
    required EditorTheme theme, 
    required ComponentVisualState componentState, 
    required bool isSelected, 
    required VoidCallback onSelect, 
    required VoidCallback onCreateBelow
    }) {

    double fontSizePercent(double percent) => theme.baseFontSize * percent / 100;

    TextStyle textStyle = TextStyle(
      fontSize: fontSizePercent(100),
      fontWeight: FontWeight.w500,
      color: theme.textColor,
    );

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(
              color: Colors.red,
              width: 4,
            ),
          ),
        ),
        child: AutoHeightRichText2(
          visualState: componentState,
          isSelected: isSelected,
          onSelect: onSelect,
          onCreateBelow: onCreateBelow,
          textStyle: textStyle,
          alignment: alignment,
          editorPadding: editorPadding,
          placeholder: def.name,
        ),
      ),
    );
  }

  Attribute<dynamic> get alignment => Attribute.centerAlignment;

  EdgeInsets get editorPadding =>
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
}



class BlockTextComponent implements Component {

  BlockTextComponent({required String id});

  @override
  String id = "";

  @override
  ComponentDef get def => BlockTextComponentDef();

  @override
  Widget buildUI({
    required EditorTheme theme, 
    required ComponentVisualState componentState, 
    required bool isSelected, 
    required VoidCallback onSelect, 
    required VoidCallback onCreateBelow
    }) {

    double fontSizePercent(double percent) => theme.baseFontSize * percent / 100;

    TextStyle textStyle = TextStyle(
      fontSize: fontSizePercent(100),
      fontFamily: 'Menlo',
      letterSpacing: 1.2,
      color: theme.textColor,
      height: 1.5,
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

  Attribute<dynamic> get alignment => Attribute.centerAlignment;

  EdgeInsets get editorPadding =>
      const EdgeInsets.symmetric(horizontal: 40, vertical: 12);
}



class QuoteComponent implements Component {

  QuoteComponent({required String id});

  @override
  String id = "";

  @override
  ComponentDef get def => QuoteComponentDef();

  @override
  Widget buildUI({
    required EditorTheme theme, 
    required ComponentVisualState componentState, 
    required bool isSelected, 
    required VoidCallback onSelect, 
    required VoidCallback onCreateBelow
    }) {

    double fontSizePercent(double percent) => theme.baseFontSize * percent / 100;

    TextStyle textStyle = TextStyle(
      fontSize: fontSizePercent(180),
      // fontFamily: 'Menlo',
      letterSpacing: 2.4,
      color: theme.subheadingColor,
      height: 1.5,
    );

    return Padding(
      padding: const EdgeInsets.all(15.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: .start,
            children: [
              Text("❝", style: 
                TextStyle(
                  fontSize: fontSizePercent(200),
                )
              ),
            ],
          ),
          AutoHeightRichText2(
            visualState: componentState,
            isSelected: isSelected,
            onSelect: onSelect,
            onCreateBelow: onCreateBelow,
            textStyle: textStyle,
            alignment: alignment,
            editorPadding: editorPadding,
            placeholder: def.name,
          ),
          AutoHeightRichText2(
            visualState: componentState,
            isSelected: isSelected,
            onSelect: onSelect,
            onCreateBelow: onCreateBelow,
            textStyle: textStyle,
            alignment: alignment,
            editorPadding: editorPadding,
            placeholder: "caption",
          ),
          Row(
            mainAxisAlignment: .end,
            children: [
              Text("❞", style: 
                TextStyle(
                  fontSize: fontSizePercent(200),
                )
              ),
            ],
          ),
        ],
      ),
    );
  }

  Attribute<dynamic> get alignment => Attribute.centerAlignment;

  EdgeInsets get editorPadding =>
      const EdgeInsets.symmetric(horizontal: 40, vertical: 12);
}





class LocationComponent implements Component {

  LocationComponent({required String id});

  @override
  String id = "";

  @override
  ComponentDef get def => LocationComponentDef();

  @override
  Widget buildUI({
    required EditorTheme theme, 
    required ComponentVisualState componentState, 
    required bool isSelected, 
    required VoidCallback onSelect, 
    required VoidCallback onCreateBelow
    }) {

    double fontSizePercent(double percent) => theme.baseFontSize * percent / 100;

    TextStyle textStyle = TextStyle(
      fontSize: fontSizePercent(100),
      fontWeight: FontWeight.w500,
      color: theme.textColor,
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

  Attribute<dynamic> get alignment => Attribute.centerAlignment;

  EdgeInsets get editorPadding =>
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
}


class CaptionComponent implements Component {

  CaptionComponent({required String id});

  @override
  String id = "";

  @override
  ComponentDef get def => CaptionComponentDef();

  @override
  Widget buildUI({
    required EditorTheme theme, 
    required ComponentVisualState componentState, 
    required bool isSelected, 
    required VoidCallback onSelect, 
    required VoidCallback onCreateBelow
    }) {

    double fontSizePercent(double percent) => theme.baseFontSize * percent / 100;

    TextStyle textStyle = TextStyle(
      fontSize: fontSizePercent(86),
      fontWeight: FontWeight.w300,
      color: theme.textColor,
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

  Attribute<dynamic> get alignment => Attribute.centerAlignment;

  EdgeInsets get editorPadding =>
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
}



class FootnoteComponent implements Component {

  FootnoteComponent({required String id});

  @override
  String id = "";

  @override
  ComponentDef get def => FootnoteComponentDef();

  @override
  Widget buildUI({
    required EditorTheme theme, 
    required ComponentVisualState componentState, 
    required bool isSelected, 
    required VoidCallback onSelect, 
    required VoidCallback onCreateBelow
    }) {

    double fontSizePercent(double percent) => theme.baseFontSize * percent / 100;

    TextStyle textStyle = TextStyle(
      fontSize: fontSizePercent(79),
      fontWeight: FontWeight.w200,
      color: theme.textColor,
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

  Attribute<dynamic> get alignment => Attribute.centerAlignment;

  EdgeInsets get editorPadding =>
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
}


