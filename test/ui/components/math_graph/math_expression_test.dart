import 'dart:math' as math;

import 'package:booklet/ui/components/math_graph/math_expression.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('precedence, powers and implicit multiplication match mathematical notation', () {
    final examples = <String, double>{
      '2 + 3*4': 14,
      '-x^2': -9,
      '(-x)^2': 9,
      '2^3^2': 512,
      '2^-2': .25,
      '2x + 1': 7,
      '(x+1)(x-1)': 8,
      'y = 2*x + 1': 7,
      '2e3 + .5': 2000.5,
      'sqrt(9) + abs(-2)': 5,
      'log(100) + ln(e)': 3,
      '2π': 2 * math.pi,
      'exp(0)': 1,
    };
    for (final entry in examples.entries) {
      expect(
        MathExpression.parse(entry.key).evaluate(3),
        closeTo(entry.value, 1e-10),
        reason: entry.key,
      );
    }
  });
  test('angles support radians and degrees including inverse functions', () {
    expect(
      MathExpression.parse('sin(x)').evaluate(math.pi / 2),
      closeTo(1, 1e-12),
    );
    expect(
      MathExpression.parse('sin(x)').evaluate(90, degrees: true),
      closeTo(1, 1e-12),
    );
    expect(
      MathExpression.parse('asin(x)').evaluate(1, degrees: true),
      closeTo(90, 1e-12),
    );
    expect(
      MathExpression.parse('acos(x)').evaluate(0),
      closeTo(math.pi / 2, 1e-12),
    );
  });
  test('undefined domains and overflow produce gaps', () {
    for (final equation in [
      '1/x',
      'ln(x)',
      'sqrt(-1)',
      'exp(1000)',
      'asin(2)',
      'sin(exp(1000))',
    ]) {
      expect(
        MathExpression.parse(equation).evaluate(0),
        isNull,
        reason: equation,
      );
    }
  });
  test('malformed input and unsupported code are rejected', () {
    for (final equation in [
      '',
      'x+',
      'sin x',
      'sin(',
      '(x+1',
      'foo(x)',
      'x; print(1)',
      'x=2',
      '1e999',
      List.filled(513, 'x').join(),
    ]) {
      expect(
        () => MathExpression.parse(equation),
        throwsFormatException,
        reason: equation,
      );
    }
  });
}
