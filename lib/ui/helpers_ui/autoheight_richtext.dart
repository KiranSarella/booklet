import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:booklet/ui/app/components/booklet_component.dart';

/*
isEditable
textStyle - font, size, textcolor, font weight, 

*/

/// This is a re-usable component. independent of rest of the app.
///
class AutoHeightRichText extends StatelessWidget {
  const AutoHeightRichText({
    super.key,
    required this.component,
    required this.isSelected,
    required this.onSelect,
    required this.onCreateBelow,
  });

  final BookletComponent component;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onCreateBelow;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected ? Colors.indigo : Colors.transparent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // if (isSelected)
        // Container(
        //   margin: const EdgeInsets.only(bottom: 8),
        //   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        //   decoration: BoxDecoration(
        //     color: Colors.white,
        //     borderRadius: BorderRadius.circular(12),
        //     border: Border.all(color: Colors.indigo.shade200),
        //   ),
        //   child: QuillSimpleToolbar(
        //     controller: entry.controller,
        //     config: const QuillSimpleToolbarConfig(
        //       showBoldButton: true,
        //       showItalicButton: true,
        //       showColorButton: true,
        //       showBackgroundColorButton: true,
        //       showClearFormat: true,
        //       showUndo: true,
        //       showRedo: true,
        //       multiRowsDisplay: false,
        //     ),
        //   ),
        // ),
        GestureDetector(
          onTap: onSelect,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: borderColor,
                width: isSelected ? 1.8 : 0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.indigo.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 54),
              child: Shortcuts(
                shortcuts: const {
                  SingleActivator(LogicalKeyboardKey.enter):
                      _CreateBelowIntent(),
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
                      controller: component.controller,
                      focusNode: component.focusNode,
                      config: const QuillEditorConfig(
                        scrollable: false,
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        expands: false,
                        textInputAction: TextInputAction.newline,
                        customStyles: DefaultStyles(color: Colors.purple),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // if (isSelected)
        //   Align(
        //     alignment: Alignment.centerRight,
        //     child: TextButton.icon(
        //       onPressed: onCreateBelow,
        //       icon: const Icon(Icons.add_circle_outline, size: 18),
        //       label: const Text('Add below'),
        //     ),
        //   ),
      ],
    );
  }
}

class _CreateBelowIntent extends Intent {
  const _CreateBelowIntent();
}

class AutoHeightRichText2 extends StatelessWidget {
  const AutoHeightRichText2({
    super.key,
    required this.component,
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

  final BookletComponent component;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onCreateBelow;
  final TextStyle textStyle;
  final Attribute<dynamic> alignment;
  final String placeholder;
  final EdgeInsets editorPadding;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected ? Colors.indigo : Colors.transparent;

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
        GestureDetector(
          onTap: onSelect,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: borderColor,
                width: isSelected ? 1.8 : 0,
              ),
              // boxShadow: isSelected
              //     ? [
              //         BoxShadow(
              //           color: Colors.indigo.withValues(alpha: 0.12),
              //           blurRadius: 12,
              //           offset: const Offset(0, 3),
              //         ),
              //       ]
              //     : null,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 54),
              child: Shortcuts(
                shortcuts: const {
                  SingleActivator(LogicalKeyboardKey.enter):
                      _CreateBelowIntent(),
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
                      controller: component.controller,
                      focusNode: component.focusNode,
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
          ),
        ),

        // ),
      ],
    );
  }
}
