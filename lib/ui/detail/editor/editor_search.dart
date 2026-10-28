import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/code_block_component.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/math_component.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' show ChangeSource;

class EditorSearchMatch {
  const EditorSearchMatch(
    this.component,
    this.select,
    this.replace,
    this.clearSelection,
  );

  final ComponentBox component;
  final VoidCallback select;
  final VoidCallback clearSelection;
  final ValueChanged<String> replace;
}

/// Finds literal occurrences in the current page's text fields.
/// Each field is searched separately so matches never span unrelated components.
List<EditorSearchMatch> findEditorMatches(
  List<ComponentBox> components,
  String query, {
  bool caseSensitive = false,
}) {
  if (query.isEmpty) return const [];
  final pattern = RegExp(RegExp.escape(query), caseSensitive: caseSensitive);
  final results = <EditorSearchMatch>[];
  for (final component in components) {
    final originalState = component.component.state;
    void addText(
      String text,
      ValueChanged<TextSelection> select,
      void Function(TextSelection, String) replace,
      VoidCallback clearSelection,
    ) {
      for (final match in pattern.allMatches(text)) {
        final selection = TextSelection(
          baseOffset: match.start,
          extentOffset: match.end,
        );
        results.add(
          EditorSearchMatch(
            component,
            () => select(selection),
            (replacement) => replace(selection, replacement),
            () {
              if (identical(component.component.state, originalState)) {
                clearSelection();
              }
            },
          ),
        );
      }
    }

    void addRichText(TextComponentState state) {
      final text = state.controller.document.toPlainText();
      // The final newline is Quill's document terminator, not page content.
      addText(
        text.substring(0, text.length - 1),
        (selection) {
          state.controller.updateSelection(selection, ChangeSource.local);
        },
        (selection, replacement) {
          state.controller.replaceText(
            selection.start,
            selection.end - selection.start,
            replacement,
            TextSelection.collapsed(
              offset: selection.start + replacement.length,
            ),
          );
        },
        () {
          final selection = state.controller.selection;
          if (selection.isValid && !selection.isCollapsed) {
            state.controller.updateSelection(
              TextSelection.collapsed(offset: selection.extentOffset),
              ChangeSource.local,
            );
          }
        },
      );
    }

    void addPlainText(TextEditingController controller) {
      addText(
        controller.text,
        (selection) => controller.selection = selection,
        (selection, replacement) {
          controller.value = TextEditingValue(
            text: controller.text.replaceRange(
              selection.start,
              selection.end,
              replacement,
            ),
            selection: TextSelection.collapsed(
              offset: selection.start + replacement.length,
            ),
          );
        },
        () {
          final selection = controller.selection;
          if (selection.isValid && !selection.isCollapsed) {
            controller.selection = TextSelection.collapsed(
              offset: selection.extentOffset,
            );
          }
        },
      );
    }

    switch (component.component.state) {
      case TextComponentState state:
        addRichText(state);
      case QuoteComponentState state:
        addRichText(state.quote);
        addRichText(state.author);
      case CodeBlockComponentState state:
        addPlainText(state.controller);
      case MathComponentState state:
        addPlainText(state.controller);
      case EmbedComponentState state:
        addPlainText(state.contentController);
      case LinkComponentState state:
        addPlainText(state.titleController);
        addPlainText(state.urlController);
      default:
        break;
    }
  }
  return results;
}
