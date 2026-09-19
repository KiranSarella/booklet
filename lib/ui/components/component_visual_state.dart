import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';



final _plainTextClipboardConfig = QuillControllerConfig(
  clipboardConfig: QuillClipboardConfig(
    enableExternalRichPaste: false,
  ),
);

class ComponentVisualState {
  ComponentVisualState(Attribute<dynamic> alignment, {List<dynamic>? delta})
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

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}
