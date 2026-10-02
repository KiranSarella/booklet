import 'package:flutter/material.dart';
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
      _state ??= TextComponentState(alignment, delta: _delta);

  // void initialize({List<dynamic>? delta}) {
  //   _delta = delta;
  //   if (delta != null && _state != null) {
  //     _state!.controller.document = Document.fromJson(delta);
  //   }
  // }

  void initialize({List<dynamic>? delta}) {
    _delta = delta;
    if (delta == null) return;

    final textState = _state ??= TextComponentState(alignment, delta: delta);
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
  final FocusNode focusNode = FocusNode();
  VoidCallback? onBackspaceAtStart;

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

class ImageComponentState extends ComponentState {
  ImageComponentState({
    String? mediaPath,
    String? imageSize,
    int? width,
    int? height,
  }) : _mediaPath = mediaPath,
       _imageSize = imageSize,
       _width = width,
       _height = height;

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
  VideoComponentState({String? mediaPath}) : _mediaPath = mediaPath;

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
  AudioComponentState({String? mediaPath}) : _mediaPath = mediaPath;

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
