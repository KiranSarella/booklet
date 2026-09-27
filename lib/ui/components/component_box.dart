import 'package:booklet/business/components_business/component_def.dart';
import 'package:booklet/ui/components/component.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/components/code_block_component.dart';
import 'package:booklet/ui/editor_themes/editor_themes.dart';
import 'package:flutter/material.dart';

class ComponentBox {
  ComponentBox({required this.component, List<dynamic>? delta}) {
    component.initialize(delta: delta);
  }

  Component component;
  final GlobalKey componentKey = GlobalKey();

  bool get isSelected => component.state.isSelected;

  set isSelected(bool value) => component.state.isSelected = value;

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
          componentState: component.state,
          isSelected: isSelected,
          onSelect: onSelect,
          onCreateBelow: onCreateBelow,
        ),
      ),
    );
  }

  bool get isTextComponent => component.def.type == ComponentType.text;

  void requestFocus() {
    final state = component.state;
    if (state is TextComponentState) {
      state.focusNode.requestFocus();
    } else if (state is CodeBlockComponentState) {
      state.focusNode.requestFocus();
    }
  }

  void dispose() {
    component.dispose();
  }
}
