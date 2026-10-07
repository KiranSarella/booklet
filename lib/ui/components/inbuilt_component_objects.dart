import 'package:booklet/business/components_business/component_def.dart';
import 'package:booklet/ui/components/component.dart';
import 'package:flutter/material.dart';
import 'package:booklet/ui/_helpers/autoheight_richtext.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:booklet/business/components_business/inbuilt_components/inbuit_components_definations.dart';

class TitleComponent with TextComponentStateOwner implements Component {
  TitleComponent({required this.id});

  @override
  final String id;

  @override
  ComponentDef get def => TitleComponentDef();

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
      fontSize: fontSizePercent(310),
      fontWeight: FontWeight.w800,
      color: theme.headingColor,
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

  @override
  Attribute<dynamic> get alignment => Attribute.centerAlignment;

  EdgeInsets get editorPadding =>
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
}

class HeadingComponent with TextComponentStateOwner implements Component {
  HeadingComponent({required this.id});

  @override
  final String id;

  @override
  ComponentDef get def => HeadingComponentDef();

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

  @override
  Attribute<dynamic> get alignment => Attribute.leftAlignment;

  EdgeInsets get editorPadding =>
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
}

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
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
}

class InlineHeadingComponent with TextComponentStateOwner implements Component {
  InlineHeadingComponent({required this.id});

  @override
  final String id;

  @override
  ComponentDef get def => InlineHeadingComponentDef();

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
      fontSize: fontSizePercent(100),
      fontWeight: FontWeight.w600,
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
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
}

class SubtitleComponent with TextComponentStateOwner implements Component {
  SubtitleComponent({required this.id});

  @override
  final String id;

  @override
  ComponentDef get def => SubtitleComponentDef();

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

  @override
  Attribute<dynamic> get alignment => Attribute.centerAlignment;

  EdgeInsets get editorPadding =>
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
}

class LabelComponent with TextComponentStateOwner implements Component {
  LabelComponent({required this.id});

  @override
  final String id;

  @override
  ComponentDef get def => LabelComponentDef();

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

  @override
  Attribute<dynamic> get alignment => Attribute.leftAlignment;

  EdgeInsets get editorPadding =>
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
}

class TextComponent with TextComponentStateOwner implements Component {
  TextComponent({required this.id});

  @override
  final String id;

  @override
  ComponentDef get def => TextComponentDef();

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
      hidePlaceholderWhenIdle: true,
    );
  }

  @override
  Attribute<dynamic> get alignment => Attribute.leftAlignment;

  EdgeInsets get editorPadding =>
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
}

class BulletedListComponent with TextComponentStateOwner implements Component {
  BulletedListComponent({required this.id});

  @override
  final String id;

  @override
  ComponentDef get def => BulletedListComponentDef();

  @override
  TextComponentState createTextComponentState({List<dynamic>? delta}) =>
      BulletedListComponentState(alignment, delta: delta);

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
    final listState = componentState as BulletedListComponentState;

    TextStyle textStyle = TextStyle(
      fontSize: fontSizePercent(100),
      fontWeight: FontWeight.w300,
      color: theme.textColor,
      height: 1.5,
    );

    return Padding(
      padding: EdgeInsets.only(left: listState.nestingLevel * 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            child: Center(
              child: Text(
                listState.symbol,
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: theme.baseFontSize,
                ),
              ),
            ),
          ),
          Expanded(
            child: AutoHeightRichText2(
              visualState: componentState,
              isSelected: isSelected,
              onSelect: onSelect,
              onCreateBelow: onCreateBelow,
              textStyle: textStyle,
              alignment: alignment,
              editorPadding: editorPadding,
              placeholder: def.placeholder,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Attribute<dynamic> get alignment => Attribute.leftAlignment;

  EdgeInsets get editorPadding =>
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
}

class NumberedListComponent with TextComponentStateOwner implements Component {
  NumberedListComponent({required this.id});

  @override
  final String id;

  @override
  ComponentDef get def => NumberedListComponentDef();

  @override
  TextComponentState createTextComponentState({List<dynamic>? delta}) =>
      NumberedListComponentState(alignment, delta: delta);

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
    final listState = componentState as NumberedListComponentState;

    TextStyle textStyle = TextStyle(
      fontSize: fontSizePercent(100),
      fontWeight: FontWeight.w300,
      color: theme.textColor,
      height: 1.5,
    );

    return Padding(
      padding: EdgeInsets.only(left: listState.nestingLevel * 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            child: Center(
              child: Text(
                listState.formatNumber(listState.sequenceNumber),
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: theme.baseFontSize,
                ),
              ),
            ),
          ),
          Expanded(
            child: AutoHeightRichText2(
              visualState: componentState,
              isSelected: isSelected,
              onSelect: onSelect,
              onCreateBelow: onCreateBelow,
              textStyle: textStyle,
              alignment: alignment,
              editorPadding: editorPadding,
              placeholder: def.placeholder,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Attribute<dynamic> get alignment => Attribute.leftAlignment;

  EdgeInsets get editorPadding =>
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
}

class ChecklistComponent with TextComponentStateOwner implements Component {
  ChecklistComponent({required this.id});

  @override
  final String id;

  @override
  ComponentDef get def => ChecklistComponentDef();

  @override
  TextComponentState createTextComponentState({List<dynamic>? delta}) =>
      ChecklistComponentState(alignment, delta: delta);

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
    final listState = componentState as ChecklistComponentState;

    TextStyle textStyle = TextStyle(
      fontSize: fontSizePercent(100),
      fontWeight: FontWeight.w300,
      color: theme.textColor,
      height: 1.5,
    );

    return Padding(
      padding: EdgeInsets.only(left: listState.nestingLevel * 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Checkbox(
            value: listState.isChecked,
            onChanged: theme.documentSettingsController.isReadOnly
                ? null
                : (checked) => listState.isChecked = checked ?? false,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          Expanded(
            child: AutoHeightRichText2(
              visualState: componentState,
              isSelected: isSelected,
              onSelect: onSelect,
              onCreateBelow: onCreateBelow,
              textStyle: textStyle,
              alignment: alignment,
              editorPadding: editorPadding,
              placeholder: def.placeholder,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Attribute<dynamic> get alignment => Attribute.leftAlignment;

  EdgeInsets get editorPadding =>
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
}

class BlockTextComponent with TextComponentStateOwner implements Component {
  BlockTextComponent({required this.id});

  @override
  final String id;

  @override
  ComponentDef get def => BlockTextComponentDef();

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

  @override
  Attribute<dynamic> get alignment => Attribute.leftAlignment;

  EdgeInsets get editorPadding =>
      const EdgeInsets.symmetric(horizontal: 40, vertical: 12);
}

class QuoteComponent implements Component {
  QuoteComponent({required this.id});

  @override
  final QuoteComponentState state = QuoteComponentState();

  @override
  Object get output => state.output;

  @override
  List<dynamic> get textDelta => state.textDelta;

  @override
  void dispose() => state.dispose();

  @override
  void initialize({List<dynamic>? delta}) {
    if (delta != null) {
      state.quote.controller.document = Document.fromJson(delta);
    }
  }

  @override
  final String id;

  @override
  ComponentDef get def => QuoteComponentDef();

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
      fontSize: fontSizePercent(160),
      // fontFamily: 'Menlo',
      letterSpacing: 2,
      color: theme.headingColor,
      height: 1.2,
    );

    TextStyle authorTextStyle = TextStyle(
      fontSize: fontSizePercent(120),
      // fontFamily: 'Menlo',
      letterSpacing: 2.4,
      color: theme.textColor,
      // height: 1.5,
    );

    return Padding(
      padding: const EdgeInsets.all(15.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: .start,
            children: [
              Text("❝", style: TextStyle(fontSize: fontSizePercent(200), color: Colors.cyan)),
            ],
          ),
          AutoHeightRichText2(
            visualState: state.quote,
            isSelected: isSelected,
            onSelect: onSelect,
            onCreateBelow: onCreateBelow,
            textStyle: textStyle,
            alignment: alignment,
            editorPadding: editorPadding,
            placeholder: def.placeholder,
            gatePointerInput: false,
          ),
          AutoHeightRichText2(
            visualState: state.author,
            isSelected: isSelected,
            onSelect: onSelect,
            onCreateBelow: onCreateBelow,
            textStyle: authorTextStyle,
            alignment: alignment,
            editorPadding: editorPadding,
            placeholder: "caption",
            gatePointerInput: false,
          ),
          Row(
            mainAxisAlignment: .end,
            children: [
              Text("❞", style: TextStyle(
                fontSize: fontSizePercent(200), color: Colors.cyan),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Attribute<dynamic> get alignment => Attribute.centerAlignment;

  EdgeInsets get editorPadding =>
      const EdgeInsets.symmetric(horizontal: 40, vertical: 12);
}

class LocationComponent with TextComponentStateOwner implements Component {
  LocationComponent({required this.id});

  @override
  final String id;

  @override
  ComponentDef get def => LocationComponentDef();

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
      placeholder: def.placeholder,
    );
  }

  @override
  Attribute<dynamic> get alignment => Attribute.leftAlignment;

  EdgeInsets get editorPadding =>
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
}

class CaptionComponent with TextComponentStateOwner implements Component {
  CaptionComponent({required this.id});

  @override
  final String id;

  @override
  ComponentDef get def => CaptionComponentDef();

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

  @override
  Attribute<dynamic> get alignment => Attribute.leftAlignment;

  EdgeInsets get editorPadding =>
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
}

class FootnoteComponent with TextComponentStateOwner implements Component {
  FootnoteComponent({required this.id});

  @override
  final String id;

  @override
  ComponentDef get def => FootnoteComponentDef();

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

  @override
  Attribute<dynamic> get alignment => Attribute.leftAlignment;

  EdgeInsets get editorPadding =>
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
}
