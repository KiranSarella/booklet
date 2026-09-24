import 'package:booklet/business/components_business/component_def.dart';
import 'package:booklet/ui/components/component_visual_state.dart';
import 'package:booklet/ui/components/component.dart';
import 'package:booklet/ui/editor_themes/editor_themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class ComponentBox {
  ComponentBox({required this.component, List<dynamic>? delta})
    : componentState = ComponentVisualState(
        Attribute.leftAlignment,
        delta: delta,
      );

  Component component;
  final ComponentVisualState componentState;
  final GlobalKey componentKey = GlobalKey();
  bool isSelected = false;

  Widget buildUI({
    required EditorTheme theme,
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
        child: component.buildUI(
          theme: theme,
          componentState: componentState,
          isSelected: isSelected,
          onSelect: onSelect,
          onCreateBelow: onCreateBelow,
        ),
      ),
    );
  }

  bool get isTextComponent => component.def.type == ComponentType.text;

  void requestFocus() {
    if (isTextComponent) {
      componentState.focusNode.requestFocus();
    }
  }

  void dispose() {
    componentState.dispose();
  }
}
