import 'package:flutter/material.dart';
import 'package:booklet/ui/helpers_ui/autoheight_richtext.dart';
import 'package:booklet/ui/editor/components/booklet_component.dart';

abstract class ComponentRenderer {
  ComponentRenderer(this.name);

  String name;
  Widget createUI({
    required BookletComponent component,
    required bool isSelected,
    required VoidCallback onSelect,
    required VoidCallback onCreateBelow,
  });
}

class TextComponent implements ComponentRenderer {
  @override
  String name = "Text";

  @override
  Widget createUI({
    required BookletComponent component,
    required bool isSelected,
    required VoidCallback onSelect,
    required VoidCallback onCreateBelow,
  }) {
    return AutoHeightRichText2(
      component: component,
      isSelected: isSelected,
      onSelect: onSelect,
      onCreateBelow: onCreateBelow,
      textStyle: TextStyle(
        fontSize: 14,
        fontWeight: .w300,
        color: const Color.fromARGB(255, 0, 8, 0),
      ),
    );
  }
}

class HeadingComponent implements ComponentRenderer {
  @override
  String name = "Heading";

  @override
  Widget createUI({
    required BookletComponent component,
    required bool isSelected,
    required VoidCallback onSelect,
    required VoidCallback onCreateBelow,
  }) {
    return AutoHeightRichText2(
      component: component,
      isSelected: isSelected,
      onSelect: onSelect,
      onCreateBelow: onCreateBelow,
      textStyle: TextStyle(
        fontSize: 22,
        fontWeight: .w600,
        color: const Color.fromARGB(255, 254, 159, 8),
      ),
    );
  }
}

class TitleComponent implements ComponentRenderer {
  @override
  String name = "Title";

  @override
  Widget createUI({
    required BookletComponent component,
    required bool isSelected,
    required VoidCallback onSelect,
    required VoidCallback onCreateBelow,
  }) {
    return AutoHeightRichText2(
      component: component,
      isSelected: isSelected,
      onSelect: onSelect,
      onCreateBelow: onCreateBelow,
      textStyle: TextStyle(
        fontSize: 32,
        fontWeight: .w700,
        color: const Color.fromARGB(255, 213, 7, 7),
      ),
    );
  }
}

class ComponentBox {
  ComponentBox({required this.componentInfo}) : component = BookletComponent();

  final ComponentInfo componentInfo;
  final BookletComponent component;

  Widget createUI({
    required bool isSelected,
    required VoidCallback onSelect,
    required VoidCallback onCreateBelow,
  }) {
    return componentInfo.renderer.createUI(
      component: component,
      isSelected: isSelected,
      onSelect: onSelect,
      onCreateBelow: onCreateBelow,
    );
  }

  void dispose() {
    component.dispose();
  }
}

class ComponentInfo {
  const ComponentInfo({required this.renderer});
  final ComponentRenderer renderer;
}
