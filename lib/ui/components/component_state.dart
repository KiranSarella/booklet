import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';

final _plainTextClipboardConfig = QuillControllerConfig(
  clipboardConfig: QuillClipboardConfig(enableExternalRichPaste: false),
);

abstract class ComponentState extends ChangeNotifier {
  bool isSelected = false;
  bool isFocused = false;

  Object? get output;

  List<dynamic>? get textDelta => null;
}

mixin TextComponentStateOwner {
  Attribute<dynamic> get alignment;

  List<dynamic>? _delta;
  TextComponentState? _state;

  TextComponentState get state =>
      _state ??= createTextComponentState(delta: _delta);

  TextComponentState createTextComponentState({List<dynamic>? delta}) =>
      TextComponentState(alignment, delta: delta);

  // void initialize({List<dynamic>? delta}) {
  //   _delta = delta;
  //   if (delta != null && _state != null) {
  //     _state!.controller.document = Document.fromJson(delta);
  //   }
  // }

  void initialize({List<dynamic>? delta}) {
    _delta = delta;
    if (delta == null) return;

    final textState = _state ??= createTextComponentState(delta: delta);
    final controller = textState.controller;

    controller.document = Document.fromJson(delta);
    controller.formatText(0, controller.document.length, alignment);
  }

  Object get output => state.output;

  List<dynamic> get textDelta => state.textDelta;

  void dispose() => state.dispose();
}

// mixin TextComponentStateOwner {
//   List<dynamic>? _delta;
//   TextComponentState? _state;

//   TextComponentState get state =>
//       _state ??= TextComponentState(Attribute.leftAlignment, delta: _delta);

//   void initialize({List<dynamic>? delta}) {
//     _delta = delta;
//     if (delta != null && _state != null) {
//       _state!.controller.document = Document.fromJson(delta);
//     }
//   }

//   Object get output => state.output;

//   List<dynamic> get textDelta => state.textDelta;

//   void dispose() => state.dispose();
// }

class TextComponentState extends ComponentState {
  TextComponentState(Attribute<dynamic> alignment, {List<dynamic>? delta})
    : controller = delta == null
          ? QuillController.basic()
          : QuillController(
              config: _plainTextClipboardConfig,
              document: Document.fromJson(delta),
              selection: const TextSelection.collapsed(offset: 0),
            ) {
    controller.addListener(notifyListeners);
    // controller.formatSelection(alignment);
    if (delta == null) {
      controller.formatText(0, controller.document.length, alignment);
    }
  }

  final QuillController controller;
  late final FocusNode focusNode = FocusNode(onKeyEvent: _handleEditorKeyEvent);
  VoidCallback? onBackspaceAtStart;

  KeyEventResult _handleEditorKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace &&
        !controller.readOnly) {
      final selection = controller.selection;
      if (selection.isCollapsed &&
          selection.extentOffset == 0 &&
          onBackspaceAtStart != null) {
        onBackspaceAtStart!();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  String get output => controller.document.toPlainText();

  @override
  List<dynamic> get textDelta => controller.document.toDelta().toJson();

  @override
  void dispose() {
    controller.removeListener(notifyListeners);
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }
}

abstract class ListItemComponentState extends TextComponentState {
  ListItemComponentState(super.alignment, {super.delta});

  int _nestingLevel = 0;

  int get nestingLevel => _nestingLevel;
  set nestingLevel(int value) {
    final nextValue = value < 0 ? 0 : value;
    if (_nestingLevel == nextValue) return;
    _nestingLevel = nextValue;
    notifyListeners();
  }
}

class BulletedListComponentState extends ListItemComponentState {
  BulletedListComponentState(
    super.alignment, {
    super.delta,
    String symbol = '•',
  }){
    this.symbol = symbol;
  }

  static const symbols = ['•', '-', '–', '→', '✓', '★', '◆'];

  String _symbol = '•';
  String get symbol => _symbol;
  set symbol(String value) {
    if (!symbols.contains(value) || _symbol == value) return;
    _symbol = value;
    notifyListeners();
  }
}

class NumberedListComponentState extends ListItemComponentState {
  NumberedListComponentState(
    super.alignment, {
    super.delta,
    String numberStyle = '1.',
  }){
    this.numberStyle = numberStyle;
  }

  static const numberStyles = ['1.', 'a.', 'i.', '1)'];

  int sequenceNumber = 1;
  String _numberStyle = '1.';
  String get numberStyle => _numberStyle;
  set numberStyle(String value) {
    if (!numberStyles.contains(value) || _numberStyle == value) return;
    _numberStyle = value;
    notifyListeners();
  }

  String formatNumber(int number) => switch (numberStyle) {
    'a.' => '${_alphabeticNumber(number)}.',
    'i.' => '${_romanNumber(number)}.',
    '1)' => '$number)',
    _ => '$number.',
  };

  String _alphabeticNumber(int number) {
    var value = number;
    final result = StringBuffer();
    while (value > 0) {
      value--;
      result.writeCharCode(97 + value % 26);
      value ~/= 26;
    }
    return result.toString().split('').reversed.join();
  }

  String _romanNumber(int number) {
    const numerals = [
      (1000, 'm'),
      (900, 'cm'),
      (500, 'd'),
      (400, 'cd'),
      (100, 'c'),
      (90, 'xc'),
      (50, 'l'),
      (40, 'xl'),
      (10, 'x'),
      (9, 'ix'),
      (5, 'v'),
      (4, 'iv'),
      (1, 'i'),
    ];
    var value = number;
    final result = StringBuffer();
    for (final (unit, numeral) in numerals) {
      while (value >= unit) {
        result.write(numeral);
        value -= unit;
      }
    }
    return result.toString();
  }
}

class ChecklistComponentState extends ListItemComponentState {
  ChecklistComponentState(super.alignment, {super.delta});

  bool _isChecked = false;
  bool get isChecked => _isChecked;
  set isChecked(bool value) {
    if (_isChecked == value) return;
    _isChecked = value;
    notifyListeners();
  }
}

class ImageComponentState extends ComponentState {
  ImageComponentState({
    this._mediaPath,
    this._imageSize,
    this._width,
    this._height,
  });

  String? _mediaPath;
  String? _imageSize;
  int? _width;
  int? _height;

  String? get mediaPath => _mediaPath;
  set mediaPath(String? value) {
    if (_mediaPath != value) {
      _mediaPath = value;
      notifyListeners();
    }
  }

  String? get imageSize => _imageSize;
  set imageSize(String? value) {
    if (_imageSize != value) {
      _imageSize = value;
      notifyListeners();
    }
  }

  int? get width => _width;
  set width(int? value) {
    if (_width != value) {
      _width = value;
      notifyListeners();
    }
  }

  int? get height => _height;
  set height(int? value) {
    if (_height != value) {
      _height = value;
      notifyListeners();
    }
  }

  @override
  String? get output => mediaPath;
}

class VideoComponentState extends ComponentState {
  VideoComponentState({this._mediaPath});

  String? _mediaPath;
  String? get mediaPath => _mediaPath;
  set mediaPath(String? value) {
    if (_mediaPath != value) {
      _mediaPath = value;
      notifyListeners();
    }
  }

  @override
  String? get output => mediaPath;
}

class AudioComponentState extends ComponentState {
  AudioComponentState({this._mediaPath});

  String? _mediaPath;
  String? get mediaPath => _mediaPath;
  set mediaPath(String? value) {
    if (_mediaPath != value) {
      _mediaPath = value;
      notifyListeners();
    }
  }

  @override
  String? get output => mediaPath;
}

class EmbedComponentState extends ComponentState {
  EmbedComponentState({String? content})
    : contentController = TextEditingController(text: content ?? ''),
      content = content ?? '' {
    contentController.addListener(_onContentChanged);
  }

  final TextEditingController contentController;
  final FocusNode focusNode = FocusNode();
  String content;

  void _onContentChanged() {
    content = contentController.text;
    notifyListeners();
  }

  void setContent(String value) {
    content = value;
    contentController.value = TextEditingValue(
      text: content,
      selection: TextSelection.collapsed(offset: content.length),
    );
  }

  @override
  String get output => content;

  @override
  void dispose() {
    contentController.removeListener(_onContentChanged);
    contentController.dispose();
    focusNode.dispose();
    super.dispose();
  }
}

class LinkComponentState extends ComponentState {
  LinkComponentState({String? url, String? title})
    : urlController = TextEditingController(text: url ?? ''),
      titleController = TextEditingController(text: title ?? ''),
      url = url ?? '',
      title = title ?? '' {
    urlController.addListener(_onUrlChanged);
    titleController.addListener(_onTitleChanged);
  }

  final TextEditingController urlController;
  final TextEditingController titleController;
  final FocusNode urlFocusNode = FocusNode();
  final FocusNode titleFocusNode = FocusNode();
  String url;
  String title;

  void _onUrlChanged() {
    url = urlController.text;
    notifyListeners();
  }

  void _onTitleChanged() {
    title = titleController.text;
    notifyListeners();
  }

  void updateUrl(String value) {
    url = value;
    notifyListeners();
  }

  void updateTitle(String value) {
    title = value;
    notifyListeners();
  }

  void setValues({required String url, String? title}) {
    this.url = url;
    this.title = title ?? '';
    urlController.text = this.url;
    titleController.text = this.title;
  }

  static Uri? parseWebUri(String value) {
    final input = value.trim();
    if (input.isEmpty) {
      return null;
    }
    final candidate = input.contains('://') ? input : 'https://$input';
    final uri = Uri.tryParse(candidate);
    if (uri == null ||
        !const ['http', 'https'].contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty) {
      return null;
    }
    return uri;
  }

  @override
  Map<String, String> get output => {'url': url, 'title': title};

  @override
  void dispose() {
    urlController.removeListener(_onUrlChanged);
    titleController.removeListener(_onTitleChanged);
    urlController.dispose();
    titleController.dispose();
    urlFocusNode.dispose();
    titleFocusNode.dispose();
    super.dispose();
  }
}

class QuoteComponentState extends ComponentState {
  QuoteComponentState({List<dynamic>? delta})
    : quote = TextComponentState(Attribute.centerAlignment, delta: delta),
      author = TextComponentState(Attribute.centerAlignment) {
    quote.addListener(notifyListeners);
    author.addListener(notifyListeners);
  }

  final TextComponentState quote;
  final TextComponentState author;

  // Relay focus to/from the quote and author fields so the component-level
  // focus state (used for the select-then-edit flow) reflects either field.
  @override
  bool get isFocused => quote.isFocused || author.isFocused;

  @override
  set isFocused(bool value) {
    quote.isFocused = value;
    author.isFocused = value;
  }

  @override
  Map<String, String> get output => {
    'quote': quote.output,
    'author': author.output,
  };

  @override
  List<dynamic> get textDelta => [
    ..._withoutDocumentTerminator(quote.textDelta),
    {'insert': '\n'},
    ...author.textDelta,
  ];

  static List<dynamic> _withoutDocumentTerminator(List<dynamic> delta) {
    final result = delta.map((operation) {
      if (operation is Map) {
        return Map<String, dynamic>.from(operation);
      }
      return operation;
    }).toList();

    if (result.isNotEmpty && result.last is Map) {
      final last = result.last as Map<String, dynamic>;
      if (last['insert'] == '\n') {
        result.removeLast();
      }
    }
    return result;
  }

  @override
  void dispose() {
    quote.removeListener(notifyListeners);
    author.removeListener(notifyListeners);
    quote.dispose();
    author.dispose();
    super.dispose();
  }
}
