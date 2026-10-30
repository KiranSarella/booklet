import 'package:flutter/material.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/business/components_business/component_def.dart';
import 'package:booklet/business/components_business/inbuilt_components/inbuit_components_definations.dart';
import 'package:booklet/ui/components/component.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/components/drawing/drawing_document.dart';
import 'package:booklet/ui/components/drawing/drawing_editor.dart';

class DrawingComponent implements Component {
  DrawingComponent({required this.id});
  @override
  final String id;
  @override
  final DrawingComponentState state = DrawingComponentState();
  @override
  ComponentDef get def => DrawingComponentDef();
  @override
  Object? get output => state.output;
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
  }) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              if (isSelected && !theme.documentSettingsController.isReadOnly)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit drawing'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        fullscreenDialog: true,
                        builder: (_) => DrawingEditor(state: state),
                      ),
                    ),
                  ),
                ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: AspectRatio(
                  aspectRatio: state.canvasSize.aspectRatio,
                  child: state.preview == null
                      ? Container(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerLow,
                          child: const Center(
                            child: Text('Drawing — select to edit'),
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            state.preview!,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
