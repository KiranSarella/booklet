import 'package:flutter/material.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/business/components_business/component_def.dart';
import 'package:booklet/business/components_business/inbuilt_components/inbuit_components_definations.dart';
import 'package:booklet/ui/components/component.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/components/statistical_chart/statistical_chart_document.dart';
import 'package:booklet/ui/components/statistical_chart/statistical_chart_editor.dart';

class StatisticalChartComponent implements Component {
  StatisticalChartComponent({required this.id});
  @override
  final String id;
  @override
  final StatisticalChartState state = StatisticalChartState();
  @override
  ComponentDef get def => StatisticalChartComponentDef();
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
      listenable: Listenable.merge([
        state,
        theme,
        theme.documentSettingsController,
      ]),
      builder: (context, _) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              if (isSelected)
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.open_in_full),
                        label: const Text('Preview chart'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            fullscreenDialog: true,
                            builder: (_) =>
                                StatisticalChartFullscreenPreview(state: state),
                          ),
                        ),
                      ),
                      if (!theme.documentSettingsController.isReadOnly)
                        TextButton.icon(
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit chart'),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              fullscreenDialog: true,
                              builder: (_) =>
                                  StatisticalChartEditor(state: state),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              StatisticalChartPreview(state: state),
            ],
          ),
        ),
      ),
    );
  }
}
