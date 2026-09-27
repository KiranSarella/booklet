import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

final _plainTextClipboardConfig = QuillControllerConfig(
  clipboardConfig: QuillClipboardConfig(enableExternalRichPaste: false),
);

abstract class ComponentState {
  bool isSelected = false;
  bool isFocused = false;

  Object? get output;

  List<dynamic>? get textDelta => null;

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

  List<dynamic> get textDelta => state.textDelta;

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
  List<dynamic> get textDelta => controller.document.toDelta().toJson();

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

class ImageComponentState extends ComponentState {
  ImageComponentState({
    this.mediaPath,
    this.imageSize,
    this.width,
    this.height,
  });

  String? mediaPath;
  String? imageSize;
  int? width;
  int? height;

  @override
  String? get output => mediaPath;

  @override
  void dispose() {}
}

class VideoComponentState extends ComponentState {
  VideoComponentState({this.mediaPath});

  String? mediaPath;

  @override
  String? get output => mediaPath;

  @override
  void dispose() {}
}

class AudioComponentState extends ComponentState {
  AudioComponentState({this.mediaPath});

  String? mediaPath;

  @override
  String? get output => mediaPath;

  @override
  void dispose() {}
}

class EmbedComponentState extends ComponentState {
  EmbedComponentState({String? content})
    : contentController = TextEditingController(text: content ?? ''),
      content = content ?? '';

  final TextEditingController contentController;
  final FocusNode focusNode = FocusNode();
  String content;

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
    contentController.dispose();
    focusNode.dispose();
  }
}

class LinkComponentState extends ComponentState {
  LinkComponentState({String? url, String? title})
    : urlController = TextEditingController(text: url ?? ''),
      titleController = TextEditingController(text: title ?? ''),
      url = url ?? '',
      title = title ?? '';

  final TextEditingController urlController;
  final TextEditingController titleController;
  final FocusNode urlFocusNode = FocusNode();
  final FocusNode titleFocusNode = FocusNode();
  String url;
  String title;

  void updateUrl(String value) => url = value;

  void updateTitle(String value) => title = value;

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
    urlController.dispose();
    titleController.dispose();
    urlFocusNode.dispose();
    titleFocusNode.dispose();
  }
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
    quote.dispose();
    author.dispose();
  }
}
