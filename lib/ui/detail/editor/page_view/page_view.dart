import 'package:booklet/business/page_content.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:flutter/material.dart';

class PageView extends StatelessWidget {
  const PageView({
    super.key,
    required this.editorTheme,
    required this.page,
    required this.onSelectComponent,
    required this.onSelectComponentRange,
    required this.onCreateEntryBelow,
    required this.onBackspaceAtStart,
    required this.onPasteText,
    required this.onTapEmptySpace,
  });

  final PageSettingsController editorTheme;
  final PageContent? page;
  final ValueChanged<ComponentBox> onSelectComponent;
  final ValueChanged<ComponentBox> onSelectComponentRange;
  final void Function(int index, TextSelection? selection) onCreateEntryBelow;
  final ValueChanged<int> onBackspaceAtStart;
  final Future<bool> Function(int index, String text) onPasteText;
  final VoidCallback onTapEmptySpace;

  int? _numberedSequenceAt(int index) {
    final components = page?.components;
    if (components == null ||
        components[index].component.state is! NumberedListComponentState) {
      return null;
    }
    final currentState =
        components[index].component.state as NumberedListComponentState;
    var number = 1;
    for (var previousIndex = index - 1; previousIndex >= 0; previousIndex--) {
      final previousState = components[previousIndex].component.state;
      if (previousState is! NumberedListComponentState ||
          previousState.nestingLevel < currentState.nestingLevel) {
        break;
      }
      if (previousState.nestingLevel == currentState.nestingLevel) {
        number++;
      }
    }
    return number;
  }

  Widget _buildComponent(int index) {
    final component = page!.components[index];
    final state = component.component.state;
    if (state is NumberedListComponentState) {
      state.sequenceNumber = _numberedSequenceAt(index) ?? 1;
    }

    return Padding(
      key: component.componentKey,
      padding: const EdgeInsets.only(bottom: 6),
      child: component.buildUI(
        theme: editorTheme,
        onSelect: () => onSelectComponent(component),
        onSelectRange: () => onSelectComponentRange(component),
        onCreateBelow: (selection) => onCreateEntryBelow(index, selection),
        onBackspaceAtStart: () => onBackspaceAtStart(index),
        onPasteText: (text) => onPasteText(index, text),
      ),
    );
  }

  List<Widget> _buildComponents() {
    final components = page?.components ?? const <ComponentBox>[];
    final widgets = <Widget>[];
    var index = 0;
    while (index < components.length) {
      if (!components[index].hasFocusBar) {
        widgets.add(_buildComponent(index++));
        continue;
      }
      final run = <Widget>[];
      while (index < components.length && components[index].hasFocusBar) {
        run.add(_buildComponent(index++));
      }
      widgets.add(
        // 14 matches the text components' horizontal editor padding, so the bar
        // lines up with the page's text margin.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: Colors.red, width: 4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: run,
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final pageTheme = Theme.of(context).copyWith(
      brightness: editorTheme.effectiveBrightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: editorTheme.effectiveBrightness,
      ),
    );

    return Theme(
      data: pageTheme,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTapEmptySpace,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: 900,
              maxWidth: editorTheme.maxContentWidth ?? double.infinity,
            ),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(color: editorTheme.pageBackgroundColor),
              clipBehavior: Clip.antiAlias,
              padding: const EdgeInsets.all(60),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _buildComponents(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
