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

class BookletEditorViewModel {
  final List<BookletComponent> components = [BookletComponent()];
  int _selectedIndex = 0;

  BookletComponent get selectedComponent => components[_selectedIndex];

  void selectComponent(int index) {
    _selectedIndex = index;
  }

  BookletComponent createComponentBelow(int index) {
    final component = BookletComponent();
    components.insert(index + 1, component);
    _selectedIndex = index + 1;
    return component;
  }

  void dispose() {
    for (final component in components) {
      component.dispose();
    }
  }
}
