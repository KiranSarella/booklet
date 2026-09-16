import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class BookletComponent {
  BookletComponent(Attribute<dynamic> alignment, {List<dynamic>? delta})
    : controller = delta == null
          ? QuillController.basic()
          : QuillController(
              document: Document.fromJson(delta),
              selection: const TextSelection.collapsed(offset: 0),
            ) {
    controller.formatSelection(alignment);
  }

  final QuillController controller;
  final FocusNode focusNode = FocusNode();

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}
