import 'package:booklet/business/components_business/component_def.dart';
import 'package:booklet/ui/components/component.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/components/code_block_component.dart';
import 'package:booklet/ui/components/math_component.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';

class ComponentBox {
  ComponentBox({required this.component, List<dynamic>? delta}) {
    component.initialize(delta: delta);
  }

  Component component;
  final GlobalKey componentKey = GlobalKey();

  bool get isSelected => component.state.isSelected;

  set isSelected(bool value) => component.state.isSelected = value;

  bool get isFocused => component.state.isFocused;

  // Any component with an editable focus target gets the select-then-edit
  // two-tap flow; pure media pickers (image/video/audio) stay single-tap.
  bool get _supportsTapToEdit =>
      component.state is TextComponentState ||
      component.state is QuoteComponentState ||
      component.state is CodeBlockComponentState ||
      component.state is MathComponentState ||
      component.state is EmbedComponentState ||
      component.state is LinkComponentState;

  Widget buildUI({
    required PageSettingsController theme,
    required VoidCallback onSelect,
    required VoidCallback onSelectRange,
    required ValueChanged<TextSelection?> onCreateBelow,
    required VoidCallback onBackspaceAtStart,
  }) {
    final isReadOnly = theme.documentSettingsController.isReadOnly;
    _applyReadOnly(isReadOnly);
    final focused = isFocused && !isReadOnly;
    final selected = isSelected;

    final state = component.state;
    if (isTextComponent && state is TextComponentState) {
      state.onBackspaceAtStart = isReadOnly ? null : onBackspaceAtStart;
    }

    Widget child = component.buildUI(
      theme: theme,
      componentState: component.state,
      isSelected: selected,
      onSelect: onSelect,
      onCreateBelow: () {
        onCreateBelow(
          isTextComponent && state is TextComponentState
              ? state.controller.selection
              : null,
        );
      },
    );

    if (_supportsTapToEdit && state is! TextComponentState) {
      // Read-only text stays interactive so it can be selected/copied; in
      // edit mode a single tap only selects, requiring a second tap to edit.
      child = AbsorbPointer(absorbing: !isReadOnly && !focused, child: child);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleTap(
        onSelect: onSelect,
        onSelectRange: onSelectRange,
        isReadOnly: isReadOnly,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: focused
                ? Colors.grey.shade400
                : (selected ? Colors.indigo : Colors.transparent),
            width: (focused || selected) ? 1.8 : 0,
          ),
        ),
        child: child,
      ),
    );
  }

  void _handleTap({
    required VoidCallback onSelect,
    required VoidCallback onSelectRange,
    required bool isReadOnly,
  }) {
    if (HardwareKeyboard.instance.isShiftPressed) {
      onSelectRange();
      return;
    }
    if (isReadOnly) {
      onSelect();
      return;
    }
    if (_supportsTapToEdit) {
      if (!isSelected) {
        onSelect();
        return;
      }
      if (!isFocused) {
        requestFocus();
        return;
      }
      return;
    }
    onSelect();
  }

  // Blocks mutation while still allowing selection/copy of the rendered text.
  void _applyReadOnly(bool isReadOnly) {
    final state = component.state;
    if (state is TextComponentState) {
      state.controller.readOnly = isReadOnly;
    } else if (state is QuoteComponentState) {
      state.quote.controller.readOnly = isReadOnly;
      state.author.controller.readOnly = isReadOnly;
    }
  }

  bool get isTextComponent => component.def.type == ComponentType.text;

  void requestFocus() {
    final state = component.state;
    if (state is TextComponentState) {
      state.focusNode.requestFocus();
    } else if (state is QuoteComponentState) {
      state.quote.focusNode.requestFocus();
    } else if (state is CodeBlockComponentState) {
      state.focusNode.requestFocus();
    } else if (state is MathComponentState) {
      state.focusNode.requestFocus();
    } else if (state is EmbedComponentState) {
      state.focusNode.requestFocus();
    } else if (state is LinkComponentState) {
      state.urlFocusNode.requestFocus();
    }
  }

  void clearFocus() {
    final state = component.state;
    state.isFocused = false;
    if (state is TextComponentState) {
      state.focusNode.unfocus();
      _collapseSelection(state);
    } else if (state is QuoteComponentState) {
      state.quote.focusNode.unfocus();
      state.author.focusNode.unfocus();
      _collapseSelection(state.quote);
      _collapseSelection(state.author);
    } else if (state is CodeBlockComponentState) {
      state.focusNode.unfocus();
    } else if (state is MathComponentState) {
      state.focusNode.unfocus();
    } else if (state is EmbedComponentState) {
      state.focusNode.unfocus();
    } else if (state is LinkComponentState) {
      state.urlFocusNode.unfocus();
    }
  }

  void _collapseSelection(TextComponentState state) {
    final selection = state.controller.selection;
    if (!selection.isValid || selection.isCollapsed) {
      return;
    }
    state.controller.updateSelection(
      TextSelection.collapsed(offset: selection.extentOffset),
      ChangeSource.local,
    );
  }

  void dispose() {
    component.dispose();
  }
}
