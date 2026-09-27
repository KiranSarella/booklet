import 'package:booklet/business/components_business/component_def.dart';
import 'package:booklet/business/components_business/inbuilt_components/inbuit_components_definations.dart';
import 'package:booklet/ui/components/component.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class MathComponentState extends ComponentState {
  MathComponentState({String? formula})
    : controller = TextEditingController(text: formula ?? '');

  final TextEditingController controller;
  final FocusNode focusNode = FocusNode();

  @override
  String get output => controller.text;

  @override
  List<dynamic> get textDelta {
    final formula = controller.text;
    return [
      {'insert': formula.endsWith('\n') ? formula : '$formula\n'},
    ];
  }

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

class MathComponent implements Component {
  MathComponent({required this.id, String? formula})
    : state = MathComponentState(formula: formula);

  @override
  final String id;

  @override
  final MathComponentState state;

  @override
  ComponentDef get def => MathComponentDef();

  @override
  Object get output => state.output;

  @override
  List<dynamic> get textDelta => state.textDelta;

  @override
  void initialize({List<dynamic>? delta}) {
    if (delta == null) {
      return;
    }
    final text = delta
        .whereType<Map>()
        .map((operation) => operation['insert'])
        .whereType<String>()
        .join();
    state.controller.text = text.endsWith('\n')
        ? text.substring(0, text.length - 1)
        : text;
  }

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
    return MathComponentView(
      state: state,
      isSelected: isSelected,
      onSelect: onSelect,
    );
  }
}

class MathComponentView extends StatefulWidget {
  const MathComponentView({
    super.key,
    required this.state,
    required this.isSelected,
    required this.onSelect,
  });

  final MathComponentState state;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  State<MathComponentView> createState() => _MathComponentViewState();
}

class _MathComponentViewState extends State<MathComponentView> {
  String _formulaForPreview(String formula) {
    final isMultilineAlignment =
        formula.contains('\n') &&
        formula.contains('&') &&
        !formula.contains(r'\begin{') &&
        !formula.contains(r'\end{');
    if (!isMultilineAlignment) {
      return formula;
    }
    return '\\begin{aligned}\n$formula\n\\end{aligned}';
  }

  @override
  void initState() {
    super.initState();
    widget.state.controller.addListener(_onFormulaChanged);
  }

  @override
  void didUpdateWidget(covariant MathComponentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.controller != widget.state.controller) {
      oldWidget.state.controller.removeListener(_onFormulaChanged);
      widget.state.controller.addListener(_onFormulaChanged);
    }
  }

  void _onFormulaChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.state.controller.removeListener(_onFormulaChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final formula = widget.state.controller.text.trim();
    final previewFormula = _formulaForPreview(formula);

    return Focus(
      onFocusChange: (hasFocus) {
        widget.state.isFocused = hasFocus;
        if (hasFocus) {
          widget.onSelect();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          border: Border.all(
            color: widget.isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant,
            width: widget.isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.isSelected) ...[
              TextField(
                controller: widget.state.controller,
                focusNode: widget.state.focusNode,
                minLines: 1,
                maxLines: 5,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                onTap: widget.onSelect,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                decoration: const InputDecoration(
                  isCollapsed: true,
                  hintText: r'Enter TeX, e.g. \frac{-b \pm \sqrt{b^2-4ac}}{2a}',
                  border: InputBorder.none,
                ),
              ),
            ] else ...[
              if (formula.isEmpty)
                Text(
                  'Tap to enter a formula',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                )
              else
                GestureDetector(
                  onTap: widget.onSelect,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Math.tex(
                      previewFormula,
                      mathStyle: MathStyle.display,
                      textStyle: TextStyle(
                        fontSize: 24,
                        color: colorScheme.onSurface,
                      ),
                      onErrorFallback: (error) => Text(
                        error.messageWithType,
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
