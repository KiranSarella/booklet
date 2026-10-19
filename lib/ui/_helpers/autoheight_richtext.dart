import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:booklet/ui/components/component_state.dart';

class _CreateBelowIntent extends Intent {
  const _CreateBelowIntent();
}

class AutoHeightRichText2 extends StatelessWidget {
  const AutoHeightRichText2({
    super.key,
    required this.visualState,
    required this.isSelected,
    required this.onSelect,
    required this.onCreateBelow,
    required this.textStyle,
    required this.alignment,
    required this.placeholder,
    this.hidePlaceholderWhenIdle = false,
    this.gatePointerInput = true,
    this.editorPadding = const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 12,
    ),
  });

  final ComponentState visualState;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onCreateBelow;
  final TextStyle textStyle;
  final Attribute<dynamic> alignment;
  final String placeholder;
  final bool hidePlaceholderWhenIdle;
  // Off when a parent already gates taps (multi-field components like quote).
  final bool gatePointerInput;
  final EdgeInsets editorPadding;

  @override
  Widget build(BuildContext context) {
    final textState = visualState as TextComponentState;
    final defaultStyles = DefaultStyles(
      paragraph: DefaultTextBlockStyle(
        textStyle,
        HorizontalSpacing.zero,
        VerticalSpacing.zero,
        VerticalSpacing.zero,
        null,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 54),
          child: Shortcuts(
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.enter): _CreateBelowIntent(),
            },
            child: Actions(
              actions: {
                _CreateBelowIntent: CallbackAction<_CreateBelowIntent>(
                  onInvoke: (_) {
                    if (isSelected) {
                      onCreateBelow();
                    }
                    return null;
                  },
                ),
              },
              child: Focus(
                onFocusChange: (hasFocus) {
                  visualState.isFocused = hasFocus;
                  if (hasFocus) {
                    onSelect();
                  }
                },
                child: AbsorbPointer(
                  absorbing:
                      gatePointerInput &&
                      !textState.controller.readOnly &&
                      !textState.isFocused,
                  child: QuillEditor.basic(
                    controller: textState.controller,
                    focusNode: textState.focusNode,
                    config: QuillEditorConfig(
                      scrollable: false,
                      // Quill remains interactive for text selection in
                      // read-only mode, but should not paint an insertion caret.
                      showCursor: !textState.controller.readOnly,
                      onKeyPressed: (event, node) {
                        final state = visualState;
                        if ((event is KeyDownEvent ||
                                event is KeyRepeatEvent) &&
                            (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                                event.logicalKey == LogicalKeyboardKey.arrowDown) &&
                            !HardwareKeyboard.instance.isShiftPressed) {
                          final selection = textState.controller.selection;
                          final moveDown =
                              event.logicalKey == LogicalKeyboardKey.arrowDown;
                          final atBoundary = selection.isCollapsed &&
                              (moveDown
                                  ? selection.extentOffset >=
                                      textState.controller.document.length - 1
                                  : selection.extentOffset == 0);
                          if (atBoundary &&
                              textState.onMoveToAdjacentTextComponent != null) {
                            textState.onMoveToAdjacentTextComponent!(moveDown);
                            return KeyEventResult.handled;
                          }
                        }
                        if ((event is KeyDownEvent ||
                                event is KeyRepeatEvent) &&
                            event.logicalKey == LogicalKeyboardKey.backspace &&
                            !textState.controller.readOnly) {
                          final selection = textState.controller.selection;
                          if (selection.isCollapsed &&
                              selection.extentOffset == 0 &&
                              textState.onBackspaceAtStart != null) {
                            textState.onBackspaceAtStart!();
                            return KeyEventResult.handled;
                          }
                        }
                        if ((event is KeyDownEvent ||
                                event is KeyRepeatEvent) &&
                            event.logicalKey == LogicalKeyboardKey.tab &&
                            state is ListItemComponentState &&
                            !state.controller.readOnly) {
                          state.nestingLevel +=
                              HardwareKeyboard.instance.isShiftPressed ? -1 : 1;
                          return KeyEventResult.handled;
                        }
                        return null;
                      },
                      padding: editorPadding,
                      expands: false,
                      placeholder:
                          (!hidePlaceholderWhenIdle ||
                              isSelected ||
                              textState.isFocused)
                          ? placeholder
                          : null,
                      textInputAction: TextInputAction.newline,
                      customStyles: defaultStyles,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // ),
      ],
    );
  }
}
