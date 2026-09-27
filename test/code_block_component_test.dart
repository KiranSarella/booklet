import 'package:booklet/ui/components/code_block_component.dart';
import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('code block accepts multiline input', (tester) async {
    final state = CodeBlockComponentState();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CodeBlockComponentView(
            state: state,
            isSelected: false,
            onSelect: () {},
          ),
        ),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.minLines, 1);
    expect(field.maxLines, 10);

    await tester.enterText(
      find.byType(EditableText),
      'first line\nsecond line',
    );
    await tester.pump();

    expect(state.controller.text, 'first line\nsecond line');

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('collapsed long code constrains the numbered gutter', (
    tester,
  ) async {
    final code = List.generate(49, (index) => 'line ${index + 1}').join('\n');
    final state = CodeBlockComponentState(code: code);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CodeBlockComponentView(
            state: state,
            isSelected: false,
            onSelect: () {},
          ),
        ),
      ),
    );

    final height = tester.getSize(find.byType(CodeField)).height;
    expect(height, lessThan(350));
    expect(state.controller.text.split('\n'), hasLength(49));

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
}
