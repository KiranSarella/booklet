import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:booklet/ui/components/component_visual_state.dart';


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
    this.editorPadding = const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 12,
    ),
  });

  final ComponentVisualState visualState;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onCreateBelow;
  final TextStyle textStyle;
  final Attribute<dynamic> alignment;
  final String placeholder;
  final EdgeInsets editorPadding;

  @override
  Widget build(BuildContext context) {
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
                  if (hasFocus) {
                    onSelect();
                  }
                },
                child: QuillEditor.basic(
                  controller: visualState.controller,
                  focusNode: visualState.focusNode,
                  config: QuillEditorConfig(
                    scrollable: false,
                    padding: editorPadding,
                    expands: false,
                    placeholder: placeholder,
                    textInputAction: TextInputAction.newline,
                    customStyles: defaultStyles,
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



