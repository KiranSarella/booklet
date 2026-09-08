import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class BookletComponent {
  BookletComponent() : controller = QuillController.basic();

  final QuillController controller;
  final FocusNode focusNode = FocusNode();

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}
