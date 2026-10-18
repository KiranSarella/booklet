import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/business/components_business/component_def.dart';
import 'package:booklet/business/components_business/inbuilt_components/inbuit_components_definations.dart';
import 'package:booklet/ui/_helpers/autoheight_richtext.dart';
import 'package:booklet/ui/components/component.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

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
