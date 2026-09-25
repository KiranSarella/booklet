import 'package:booklet/business/components_business/component_def.dart';
import 'package:booklet/ui/editor_themes/editor_themes.dart';
import 'package:flutter/material.dart';
import 'package:booklet/ui/components/component_state.dart';

abstract class Component {
  String get id;
  ComponentDef get def;
  ComponentState get state;

  void initialize({List<dynamic>? delta}) {}

  Widget buildUI({
    required EditorTheme theme,
    required ComponentState componentState,
    required bool isSelected,
    required VoidCallback onSelect,
    required VoidCallback onCreateBelow,
  });

  Object? get output => state.output;

  List<dynamic>? get textDelta => state.textDelta;

  void dispose() => state.dispose();
}
