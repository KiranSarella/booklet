import 'package:booklet/ui/components/math_component.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('math block switches between preview and multiline editor', (
    tester,
  ) async {
    final state = MathComponentState(formula: r'x^2 + y^2 = z^2');
    var isSelected = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => MathComponentView(
              state: state,
              isSelected: isSelected,
              onSelect: () => setState(() => isSelected = true),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Math), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.byType(Math));
    await tester.pump();
    expect(find.byType(Math), findsNothing);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.maxLines, 5);

    await tester.enterText(
      find.byType(EditableText),
      r'\frac{a}{b}'
      '\n+c',
    );
    await tester.pump();

    expect(
      state.controller.text,
      r'\frac{a}{b}'
      '\n+c',
    );
    expect(find.byType(Math), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('math block renders raw multiline alignment formulas', (
    tester,
  ) async {
    const formula =
        r'S &= 1 + 2 + \cdots + n'
        '\n'
        r'S &= n + (n-1) + \cdots + 1'
        '\n'
        r'2S &= n(n+1)'
        '\n'
        r'S &= \frac{n(n+1)}{2}';
    final state = MathComponentState(formula: formula);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MathComponentView(
            state: state,
            isSelected: false,
            onSelect: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    final math = tester.widget<Math>(find.byType(Math));
    expect(math.parseError, isNull);
    expect(state.controller.text, formula);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
}
