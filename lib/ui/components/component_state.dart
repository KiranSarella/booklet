import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

final _plainTextClipboardConfig = QuillControllerConfig(
  clipboardConfig: QuillClipboardConfig(
    enableExternalRichPaste: false,
  ),
);

abstract class ComponentState {
  bool isSelected = false;
  bool isFocused = false;

  Object? get output;

  void dispose();
}

mixin TextComponentStateOwner {
  List<dynamic>? _delta;
  TextComponentState? _state;

  TextComponentState get state =>
      _state ??= TextComponentState(Attribute.leftAlignment, delta: _delta);

  void initialize({List<dynamic>? delta}) {
    _delta = delta;
    if (delta != null && _state != null) {
      _state!.controller.document = Document.fromJson(delta);
    }
  }

  Object get output => state.output;

  void dispose() => state.dispose();
}

class TextComponentState extends ComponentState {
  TextComponentState(Attribute<dynamic> alignment, {List<dynamic>? delta})
    : controller = delta == null
          ? QuillController.basic()
          : QuillController(
              config: _plainTextClipboardConfig,
              document: Document.fromJson(delta),
              selection: const TextSelection.collapsed(offset: 0),
            ) {
    controller.formatSelection(alignment);
  }

  final QuillController controller;
  final FocusNode focusNode = FocusNode();

  @override
  String get output => controller.document.toPlainText();

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

class ImageComponentState extends ComponentState {
  ImageComponentState({this.mediaPath});

  String? mediaPath;

  @override
  String? get output => mediaPath;

  @override
  void dispose() {}
}

class QuoteComponentState extends ComponentState {
  QuoteComponentState({List<dynamic>? delta})
    : quote = TextComponentState(Attribute.centerAlignment, delta: delta),
      author = TextComponentState(Attribute.centerAlignment);

  final TextComponentState quote;
  final TextComponentState author;

  @override
  Map<String, String> get output => {
    'quote': quote.output,
    'author': author.output,
  };

  @override
  void dispose() {
    quote.dispose();
    author.dispose();
  }
}
