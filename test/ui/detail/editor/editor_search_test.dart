import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/text_component.dart';
import 'package:booklet/ui/detail/editor/editor_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ComponentBox first;
  late ComponentBox second;
  setUp(() {
    first = ComponentBox(
      component: TextComponent(id: 'first'),
      delta: [
        {'insert': 'Hello hello a.b 😀hello\n'},
      ],
    );
    second = ComponentBox(
      component: TextComponent(id: 'second'),
      delta: [
        {'insert': 'HELLO\n'},
      ],
    );
  });
  tearDown(() {
    first.dispose();
    second.dispose();
  });

  test('finds every occurrence in page order and selects UTF-16 offsets', () {
    final matches = findEditorMatches([first, second], 'hello');
    expect(matches.map((m) => m.component), [first, first, first, second]);
    matches[2].select();
    final state = first.component.state as TextComponentState;
    expect(
      state.controller.selection,
      const TextSelection(baseOffset: 18, extentOffset: 23),
    );
    expect(state.output, 'Hello hello a.b 😀hello\n');
  });

  test('clears a search highlight without changing text', () {
    final match = findEditorMatches([first], 'hello').first;
    final state = first.component.state as TextComponentState;
    match.select();
    expect(state.controller.selection.isCollapsed, isFalse);
    match.clearSelection();
    expect(state.controller.selection.isCollapsed, isTrue);
    expect(state.output, 'Hello hello a.b 😀hello\n');
  });

  test('case-sensitive search distinguishes letter case', () {
    expect(
      findEditorMatches([first, second], 'hello', caseSensitive: true),
      hasLength(2),
    );
    expect(
      findEditorMatches([first, second], 'HELLO', caseSensitive: true),
      hasLength(1),
    );
  });

  test('treats queries literally and ignores the document terminator', () {
    expect(findEditorMatches([first, second], 'a.b'), hasLength(1));
    expect(findEditorMatches([first, second], 'a+b'), isEmpty);
    expect(findEditorMatches([first, second], '\n'), isEmpty);
    expect(findEditorMatches([first, second], ''), isEmpty);
    expect(findEditorMatches([first, second], 'missing'), isEmpty);
    expect(findEditorMatches([first, second], 'helloHELLO'), isEmpty);
  });
}
