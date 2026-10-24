import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/business/components_business/component_def.dart';
import 'package:booklet/business/components_business/inbuilt_components/inbuit_components_definations.dart';
import 'package:booklet/ui/_helpers/autoheight_richtext.dart';
import 'package:booklet/ui/components/component.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

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
      color: theme.styleColor,
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
              Text(
                "❝",
                style: TextStyle(
                  fontSize: fontSizePercent(200),
                  color: theme.styleColor,
                ),
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
            placeholder: def.placeholder,
            gatePointerInput: false,
          ),
          if (canShowCaption)
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
              Text(
                "❞",
                style: TextStyle(
                  fontSize: fontSizePercent(200),
                  color: theme.styleColor,
                ),
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

  bool get canShowCaption {
    bool isActive = state.isSelected || state.isFocused;
    if (isActive) {
      return true;
    } else {
      // not active
      if (state.author.output.trim().isNotEmpty) {
        return true;
      }
    }

    return false;
  }
}
