import 'package:booklet/ui/components/inbuilt_components/component_defs/code_block_component.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('read-only code blocks disable editing and language changes', (
    tester,
  ) async {
    final state = CodeBlockComponentState(code: 'final answer = 42;');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CodeBlockComponentView(
            state: state,
            isSelected: false,
            readOnly: true,
            onSelect: () {},
          ),
        ),
      ),
    );
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    expect(
      tester
          .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
          .onChanged,
      isNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

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
    expect(field.maxLines, isNull);

    await tester.enterText(
      find.byType(EditableText),
      'first line\nsecond line',
    );
    await tester.pump();

    expect(state.controller.text, 'first line\nsecond line');

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('long code grows fully and wraps within the page', (
    tester,
  ) async {
    final code = List.generate(49, (index) => 'line ${index + 1}').join('\n');
    final state = CodeBlockComponentState(code: code);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CodeBlockComponentView(
              state: state,
              isSelected: false,
              onSelect: () {},
            ),
          ),
        ),
      ),
    );

    final height = tester.getSize(find.byType(TextField)).height;
    expect(height, greaterThan(900));
    expect(find.byType(PopupMenuButton<bool>), findsNothing);
    expect(tester.takeException(), isNull);
    expect(state.controller.text.split('\n'), hasLength(49));

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
  testWidgets('code font follows size increases and decreases', (tester) async {
    final state = CodeBlockComponentState(code: 'final answer = 42;');
    for (final size in [14.0, 20.0, 12.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeBlockComponentView(
              state: state,
              fontSize: size,
              isSelected: false,
              onSelect: () {},
            ),
          ),
        ),
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).style!.fontSize,
        size,
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
}
