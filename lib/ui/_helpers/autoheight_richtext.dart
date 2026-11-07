import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';
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
  Widget build(BuildContext context) => ValueListenableBuilder<Map<int, Color>>(
    valueListenable: (visualState as TextComponentState).readingHighlights,
    builder: (context, _, _) => _buildEditor(context),
  );

  Widget _buildEditor(BuildContext context) {
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
                                event.logicalKey ==
                                    LogicalKeyboardKey.arrowDown) &&
                            !HardwareKeyboard.instance.isShiftPressed) {
                          final selection = textState.controller.selection;
                          final moveDown =
                              event.logicalKey == LogicalKeyboardKey.arrowDown;
                          final atBoundary =
                              selection.isCollapsed &&
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
                      textSpanBuilder:
                          (context, node, offset, text, style, recognizer) {
                            final isPlaceholder = node.style.containsKey(
                              Attribute.placeholder.key,
                            );
                            final effectiveStyle = textStyle
                                .merge(style)
                                .copyWith(
                                  color: isPlaceholder
                                      ? Colors.grey.withValues(alpha: 0.6)
                                      : style?.color ?? textStyle.color,
                                );
                            final family = effectiveStyle.fontFamily;
                            // Google Fonts registers each variant as a separate
                            // family. Changing weight alone keeps the regular
                            // font file, so select the matching variant here.
                            final fontName = family == null
                                ? null
                                : _googleFontNames[family.split('_').first];
                            final spanStyle = fontName == null
                                ? style
                                : GoogleFonts.getFont(
                                    fontName,
                                    textStyle: effectiveStyle,
                                  );
                            if (textState.controller.readOnly &&
                                textState.readingHighlights.value.isNotEmpty &&
                                !isPlaceholder) {
                              final colors = textState.readingHighlights.value;
                              final start = node.documentOffset + offset;
                              final children = <TextSpan>[];
                              var runStart = 0;
                              while (runStart < text.length) {
                                final color = colors[start + runStart];
                                var end = runStart + 1;
                                while (end < text.length &&
                                    colors[start + end] == color) {
                                  end++;
                                }
                                children.add(
                                  TextSpan(
                                    text: text.substring(runStart, end),
                                    style: color == null
                                        ? null
                                        : TextStyle(
                                            backgroundColor: color,
                                            color: Colors.black87,
                                          ),
                                    recognizer: recognizer,
                                  ),
                                );
                                runStart = end;
                              }
                              return TextSpan(
                                style: spanStyle,
                                children: children,
                              );
                            }
                            return TextSpan(
                              text: text,
                              style: spanStyle,
                              recognizer: recognizer,
                              mouseCursor: recognizer == null
                                  ? null
                                  : SystemMouseCursors.click,
                            );
                          },
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

final _googleFontNames = {
  for (final name in GoogleFonts.asMap().keys) name.replaceAll(' ', ''): name,
};
