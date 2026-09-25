import 'package:booklet/business/components_business/component_def.dart';
import 'package:booklet/ui/components/component.dart';
import 'package:flutter/material.dart';
import 'package:booklet/ui/_helpers/autoheight_richtext.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/editor_themes/editor_themes.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:booklet/business/components_business/inbuilt_components/inbuit_components_definations.dart';


class TitleComponent with TextComponentStateOwner implements Component {

  TitleComponent({required String id});

  @override
  String id = "";

  @override
  ComponentDef get def => TitleComponentDef();

  @override
  Widget buildUI({
    required EditorTheme theme, 
    required ComponentState componentState,
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


class HeadingComponent with TextComponentStateOwner implements Component {

  HeadingComponent({required String id});

  @override
  String id = "";

  @override
  ComponentDef get def => HeadingComponentDef();

  @override
  Widget buildUI({
    required EditorTheme theme, 
    required ComponentState componentState,
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



class SubheadingComponent with TextComponentStateOwner implements Component {

  SubheadingComponent({required String id});

  @override
  String id = "";

  @override
  ComponentDef get def => SubheadingComponentDef();

  @override
  Widget buildUI({
    required EditorTheme theme, 
    required ComponentState componentState,
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




class InlineHeadingComponent with TextComponentStateOwner implements Component {

  InlineHeadingComponent({required String id});

  @override
  String id = "";

  @override
  ComponentDef get def => InlineHeadingComponentDef();

  @override
  Widget buildUI({
    required EditorTheme theme, 
    required ComponentState componentState,
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



class SubtitleComponent with TextComponentStateOwner implements Component {

  SubtitleComponent({required String id});

  @override
  String id = "";

  @override
  ComponentDef get def => SubtitleComponentDef();

  @override
  Widget buildUI({
    required EditorTheme theme, 
    required ComponentState componentState,
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



class LabelComponent with TextComponentStateOwner implements Component {

  LabelComponent({required String id});

  @override
  String id = "";

  @override
  ComponentDef get def => LabelComponentDef();

  @override
  Widget buildUI({
    required EditorTheme theme, 
    required ComponentState componentState,
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


class TextComponent with TextComponentStateOwner implements Component {

  TextComponent({required String id});

  @override
  String id = "";

  @override
  ComponentDef get def => TextComponentDef();

  @override
  Widget buildUI({
    required EditorTheme theme, 
    required ComponentState componentState,
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


class DashedListComponent with TextComponentStateOwner implements Component {

  DashedListComponent({required String id});

  @override
  String id = "";

  @override
  ComponentDef get def => DashedListComponentDef();

  @override
  Widget buildUI({
    required EditorTheme theme, 
    required ComponentState componentState,
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



class NumberedListComponent with TextComponentStateOwner implements Component {

  NumberedListComponent({required String id});

  @override
  String id = "";

  @override
  ComponentDef get def => NumberedListComponentDef();

  @override
  Widget buildUI({
    required EditorTheme theme, 
    required ComponentState componentState,
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



class ChecklistComponent with TextComponentStateOwner implements Component {

  ChecklistComponent({required String id});

  @override
  String id = "";

  @override
  ComponentDef get def => ChecklistComponentDef();

  @override
  Widget buildUI({
    required EditorTheme theme, 
    required ComponentState componentState,
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



class FocusComponent with TextComponentStateOwner implements Component {

  FocusComponent({required String id});

  @override
  String id = "";

  @override
  ComponentDef get def => FocusComponentDef();

  @override
  Widget buildUI({
    required EditorTheme theme, 
    required ComponentState componentState,
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



class BlockTextComponent with TextComponentStateOwner implements Component {

  BlockTextComponent({required String id});

  @override
  String id = "";

  @override
  ComponentDef get def => BlockTextComponentDef();

  @override
  Widget buildUI({
    required EditorTheme theme, 
    required ComponentState componentState,
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
  String id = "";

  @override
  ComponentDef get def => QuoteComponentDef();

  @override
  Widget buildUI({
    required EditorTheme theme, 
    required ComponentState componentState,
    required bool isSelected, 
    required VoidCallback onSelect, 
    required VoidCallback onCreateBelow
    }) {

    double fontSizePercent(double percent) => theme.baseFontSize * percent / 100;

    TextStyle textStyle = TextStyle(
      fontSize: fontSizePercent(160),
      // fontFamily: 'Menlo',
      letterSpacing: 2,
      color: theme.subheadingColor,
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
              Text("❝", style: 
                TextStyle(
                  fontSize: fontSizePercent(200),
                )
              ),
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
            placeholder: def.name,
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

class ImageComponent implements Component {
  ImageComponent({required this.id, String? mediaPath})
    : state = ImageComponentState(mediaPath: mediaPath);

  @override
  final String id;

  @override
  final ImageComponentState state;

  @override
  Object? get output => state.output;

  @override
  List<dynamic>? get textDelta => state.textDelta;

  @override
  void initialize({List<dynamic>? delta}) {}

  @override
  void dispose() => state.dispose();

  @override
  ComponentDef get def => ImageComponentDef();

  @override
  Widget buildUI({
    required EditorTheme theme,
    required ComponentState componentState,
    required bool isSelected,
    required VoidCallback onSelect,
    required VoidCallback onCreateBelow,
  }) {
    final path = state.mediaPath;
    return GestureDetector(
      onTap: onSelect,
      child: path == null || path.isEmpty
          ? const SizedBox(
              height: 180,
              child: Center(child: Text('Choose an image')),
            )
          : Image.network(
              path,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const SizedBox(
                height: 180,
                child: Center(child: Text('Image unavailable')),
              ),
            ),
    );
  }
}





class LocationComponent with TextComponentStateOwner implements Component {

  LocationComponent({required String id});

  @override
  String id = "";

  @override
  ComponentDef get def => LocationComponentDef();

  @override
  Widget buildUI({
    required EditorTheme theme, 
    required ComponentState componentState,
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


class CaptionComponent with TextComponentStateOwner implements Component {

  CaptionComponent({required String id});

  @override
  String id = "";

  @override
  ComponentDef get def => CaptionComponentDef();

  @override
  Widget buildUI({
    required EditorTheme theme, 
    required ComponentState componentState,
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



class FootnoteComponent with TextComponentStateOwner implements Component {

  FootnoteComponent({required String id});

  @override
  String id = "";

  @override
  ComponentDef get def => FootnoteComponentDef();

  @override
  Widget buildUI({
    required EditorTheme theme, 
    required ComponentState componentState,
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


