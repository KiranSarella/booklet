import 'package:booklet/business/components_business/component_def.dart';
import 'package:booklet/ui/components/inbuilt_component_objects.dart';
import 'package:booklet/ui/editor_themes/editor_themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:booklet/ui/components/component_visual_state.dart';

abstract class Component {
  String get id;
  ComponentDef get def;

  Widget buildUI({
    required EditorTheme theme,
    required ComponentVisualState componentState,
    required bool isSelected,
    required VoidCallback onSelect,
    required VoidCallback onCreateBelow,
  });

}
