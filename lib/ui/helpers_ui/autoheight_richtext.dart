import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';

class AutoHeightRichText extends StatelessWidget {
  const AutoHeightRichText({
    super.key,
    required this.entry,
    required this.isSelected,
    required this.onSelect,
    required this.onCreateBelow,
  });

  final RichTextEntry entry;
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
                      controller: entry.controller,
                      focusNode: entry.focusNode,
                      config: const QuillEditorConfig(
                        scrollable: false,
                        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        expands: false,
                        textInputAction: TextInputAction.newline,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (isSelected)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onCreateBelow,
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Add below'),
            ),
          ),
      ],
    );
  }
}


class RichTextEntry {
  RichTextEntry() : controller = QuillController.basic();

  final QuillController controller;
  final FocusNode focusNode = FocusNode();
}

class _CreateBelowIntent extends Intent {
  const _CreateBelowIntent();
}
