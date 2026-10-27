import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/business/components_business/component_def.dart';
import 'package:booklet/business/components_business/inbuilt_components/inbuit_components_definations.dart';
import 'package:booklet/ui/components/component.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/detail/assets_viewer/assets_viewer.dart';
import 'package:flutter/material.dart';

class AssetsComponent implements Component {
  AssetsComponent({required this.id});

  @override
  final String id;
  @override
  final AssetsComponentState state = AssetsComponentState();
  @override
  ComponentDef get def => AssetsComponentDef();
  @override
  Object get output => state.output;
  @override
  List<dynamic>? get textDelta => null;
  @override
  void initialize({List<dynamic>? delta}) {}
  @override
  void dispose() => state.dispose();

  @override
  Widget buildUI({
    required PageSettingsController theme,
    required ComponentState componentState,
    required bool isSelected,
    required VoidCallback onSelect,
    required VoidCallback onCreateBelow,
  }) => Builder(
    builder: (context) {
      final isReadOnly = theme.documentSettingsController.isReadOnly;
      return Listener(
        onPointerDown: (_) => onSelect(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 360),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: AssetsViewer(
              shrinkWrap: true,
              controller: state.controller,
              focusNode: state.focusNode,
              onFocusChange: (focused) {
                state.isFocused = focused;
                if (focused) onSelect();
              },
              isReadOnly: isReadOnly,
              onExpand: () => showDialog<void>(
                context: context,
                builder: (context) => Dialog.fullscreen(
                  child: SafeArea(
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            tooltip: 'Close preview',
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        Expanded(
                          child: AssetsViewer(
                            controller: state.controller,
                            isReadOnly: isReadOnly,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
