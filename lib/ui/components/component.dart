import 'package:booklet/business/components_business/component_def.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:booklet/ui/components/component_state.dart';

abstract class Component {
  String get id;
  ComponentDef get def;
  ComponentState get state;

  void initialize({List<dynamic>? delta}) {}

  Widget buildUI({
    required PageSettingsController theme,
    required ComponentState componentState,
    required bool isSelected,
    required VoidCallback onSelect,
    required VoidCallback onCreateBelow,
  });

  Object? get output => state.output;

  List<dynamic>? get textDelta => state.textDelta;

  void dispose() => state.dispose();
}
