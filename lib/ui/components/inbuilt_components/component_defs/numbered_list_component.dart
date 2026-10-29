import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/business/components_business/component_def.dart';
import 'package:booklet/business/components_business/inbuilt_components/inbuit_components_definations.dart';
import 'package:booklet/ui/_helpers/autoheight_richtext.dart';
import 'package:booklet/ui/components/component.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

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
      fontFamily: theme.bodyFontFamily,
      fontSize: fontSizePercent(100),
      fontWeight: FontWeight.w300,
      color: theme.textColor,
      height: 1.5,
    );

    return Padding(
      padding: EdgeInsets.only(left: listState.nestingLevel * 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: editorPadding.top),
            child: SizedBox(
              width: 52,
              child: _EditableListNumber(
                state: listState,
                color: theme.styleColor,
                fontSize: theme.baseFontSize,
                fontFamily: theme.bodyFontFamily,
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

class _EditableListNumber extends StatefulWidget {
  const _EditableListNumber({
    required this.state,
    required this.color,
    required this.fontSize,
    required this.fontFamily,
  });

  final NumberedListComponentState state;
  final Color color;
  final double fontSize;
  final String? fontFamily;

  @override
  State<_EditableListNumber> createState() => _EditableListNumberState();
}

class _EditableListNumberState extends State<_EditableListNumber> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.state.formatNumber(widget.state.sequenceNumber),
    );
    _focusNode = FocusNode();
    widget.state.addListener(_syncNumber);
  }

  @override
  void didUpdateWidget(covariant _EditableListNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      oldWidget.state.removeListener(_syncNumber);
      widget.state.addListener(_syncNumber);
      _syncNumber();
    }
  }

  void _syncNumber() {
    if (_focusNode.hasFocus) return;
    final text = widget.state.formatNumber(widget.state.sequenceNumber);
    if (_controller.text != text) _controller.text = text;
  }

  void _commitNumber(String input) {
    final match = RegExp(r'^\s*(\d+)\s*[.)]?\s*$').firstMatch(input);
    final value = match == null ? null : int.tryParse(match.group(1)!);
    if (value == null || value < 1) {
      _syncNumber();
      return;
    }
    widget.state.setCustomSequenceNumber(value);
    _focusNode.unfocus();
    _syncNumber();
  }

  @override
  void dispose() {
    widget.state.removeListener(_syncNumber);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _syncNumber();
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      onSubmitted: _commitNumber,
      onTap: () => _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      ),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: widget.fontFamily,
        color: widget.color,
        fontSize: widget.fontSize,
        height: 1.5,
      ),
      decoration: const InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
      keyboardType: TextInputType.number,
    );
  }
}
