import 'dart:math' as math;

/// A small mathematical grammar. Expressions never execute Dart or other code.
class MathExpression {
  MathExpression._(this._root);
  final _Node _root;

  factory MathExpression.parse(String source) {
    final normalized = source
        .replaceFirst(RegExp(r'^\s*y\s*=\s*', caseSensitive: false), '')
        .replaceAll('π', 'pi')
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('−', '-')
        .replaceAll('**', '^');
    if (normalized.length > 512) {
      throw const FormatException('Keep equations within 512 characters.');
    }
    return MathExpression._(_Parser(normalized).parse());
  }

  /// Undefined values and overflow create a gap in the plotted curve.
  double? evaluate(double x, {bool degrees = false}) {
    final value = _root.evaluate(x, degrees);
    return value.isFinite ? value : null;
  }
}

abstract class _Node {
  double evaluate(double x, bool degrees);
}

class _Constant extends _Node {
  _Constant(this.value);
  final double value;
  @override
  double evaluate(double x, bool degrees) => value;
}

class _Variable extends _Node {
  @override
  double evaluate(double x, bool degrees) => x;
}

class _Binary extends _Node {
  _Binary(this.operator, this.left, this.right);
  final String operator;
  final _Node left, right;
  @override
  double evaluate(double x, bool degrees) {
    final a = left.evaluate(x, degrees), b = right.evaluate(x, degrees);
    return switch (operator) {
      '+' => a + b,
      '-' => a - b,
      '*' => a * b,
      '/' => a / b,
      '^' => math.pow(a, b).toDouble(),
      _ => double.nan,
    };
  }
}

class _Function extends _Node {
  _Function(this.name, this.argument);
  final String name;
  final _Node argument;
  static const names = {
    'sin',
    'cos',
    'tan',
    'asin',
    'acos',
    'atan',
    'sqrt',
    'abs',
    'ln',
    'log',
    'log10',
    'exp',
  };
  @override
  double evaluate(double x, bool degrees) {
    final value = argument.evaluate(x, degrees);
    final angle = degrees ? value * math.pi / 180 : value;
    final inverseScale = degrees ? 180 / math.pi : 1.0;
    return switch (name) {
      'sin' => math.sin(angle),
      'cos' => math.cos(angle),
      'tan' => math.tan(angle),
      'asin' => math.asin(value) * inverseScale,
      'acos' => math.acos(value) * inverseScale,
      'atan' => math.atan(value) * inverseScale,
      'sqrt' => math.sqrt(value),
      'abs' => value.abs(),
      'ln' => math.log(value),
      'log' || 'log10' => math.log(value) / math.ln10,
      'exp' => math.exp(value),
      _ => double.nan,
    };
  }
}

class _Parser {
  _Parser(String source) {
    final token = RegExp(
      r'\s+|(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?|[a-zA-Z]+[0-9]*|[+\-*/^()]',
    );
    var offset = 0;
    while (offset < source.length) {
      final match = token.matchAsPrefix(source, offset);
      if (match == null) {
        throw FormatException(
          'Unexpected character at position ${offset + 1}.',
        );
      }
      final value = match.group(0)!.trim().toLowerCase();
      if (value.isNotEmpty) tokens.add(value);
      offset = match.end;
    }
    if (tokens.length > 256) {
      throw const FormatException('This equation is too complex.');
    }
  }
  final tokens = <String>[];
  int index = 0;
  String? get current => index < tokens.length ? tokens[index] : null;
  bool take(String token) {
    if (current != token) return false;
    index++;
    return true;
  }

  _Node parse() {
    if (tokens.isEmpty) {
      throw const FormatException('Enter an equation such as x^2 or sin(x).');
    }
    final result = sum();
    if (current != null) throw FormatException('Unexpected "$current".');
    return result;
  }

  _Node sum() {
    var node = product();
    while (current == '+' || current == '-') {
      final op = tokens[index++];
      node = _Binary(op, node, product());
    }
    return node;
  }

  _Node product() {
    var node = unary();
    while (current != null) {
      if (current == '*' || current == '/') {
        final op = tokens[index++];
        node = _Binary(op, node, unary());
      } else if (current == '(' ||
          double.tryParse(current!) != null ||
          RegExp(r'^[a-z]').hasMatch(current!)) {
        node = _Binary('*', node, unary());
      } else {
        break;
      }
    }
    return node;
  }

  _Node unary() {
    if (take('+')) return unary();
    if (take('-')) return _Binary('-', _Constant(0), unary());
    return power();
  }

  _Node power() {
    final node = primary();
    return take('^') ? _Binary('^', node, unary()) : node;
  }

  _Node primary() {
    final value = current;
    if (value == null) {
      throw const FormatException('The equation is incomplete.');
    }
    if (take('(')) {
      final node = sum();
      if (!take(')')) {
        throw const FormatException('Missing closing parenthesis.');
      }
      return node;
    }
    index++;
    final number = double.tryParse(value);
    if (number != null) {
      if (!number.isFinite) {
        throw const FormatException('Numbers must be finite.');
      }
      return _Constant(number);
    }
    if (value == 'x') return _Variable();
    if (value == 'pi') return _Constant(math.pi);
    if (value == 'e') return _Constant(math.e);
    if (!_Function.names.contains(value)) {
      throw FormatException(
        'Unknown symbol "$value". Use x, pi, e, or a supported function.',
      );
    }
    if (!take('(')) {
      throw FormatException('Use parentheses, for example $value(x).');
    }
    final node = sum();
    if (!take(')')) throw const FormatException('Missing closing parenthesis.');
    return _Function(value, node);
  }
}
