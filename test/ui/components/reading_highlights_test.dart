import 'package:booklet/ui/components/component_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reading highlights recolor and remove without changing content', () {
    final state = TextComponentState(
      Attribute.leftAlignment,
      delta: [
        {'insert': 'Hello reader\n'},
      ],
    );
    addTearDown(state.dispose);
    final original = state.textDelta;
    state.controller.readOnly = true;
    state.controller.updateSelection(
      const TextSelection(baseOffset: 1, extentOffset: 5),
      ChangeSource.local,
    );
    state.highlightReadingSelection(Colors.yellow);
    expect(state.readingHighlights.value.keys, [1, 2, 3, 4]);
    state.highlightReadingSelection(Colors.blue);
    expect(state.readingHighlights.value.values, everyElement(Colors.blue));
    state.highlightReadingSelection(null);
    expect(state.readingHighlights.value, isEmpty);
    expect(state.textDelta, original);
  });

  test('editing mode and collapsed selections cannot add highlights', () {
    final state = TextComponentState(
      Attribute.leftAlignment,
      delta: [
        {'insert': 'Hello\n'},
      ],
    );
    addTearDown(state.dispose);
    state.controller.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 3),
      ChangeSource.local,
    );
    state.highlightReadingSelection(Colors.yellow);
    expect(state.readingHighlights.value, isEmpty);
    state.controller.readOnly = true;
    state.controller.updateSelection(
      const TextSelection.collapsed(offset: 2),
      ChangeSource.local,
    );
    state.highlightReadingSelection(Colors.yellow);
    expect(state.readingHighlights.value, isEmpty);
  });
}
