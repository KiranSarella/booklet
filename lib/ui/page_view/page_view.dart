import 'package:booklet/business/page_content.dart';
import 'package:booklet/ui/components/components.dart';
import 'package:booklet/ui/editor_themes/editor_themes.dart';
import 'package:flutter/material.dart';

class PageView extends StatelessWidget {
  const PageView({
    super.key,
    required this.editorTheme,
    required this.page,
    required this.onSelectComponent,
    required this.onCreateEntryBelow,
    required this.onTapEmptySpace,
  });

  final EditorTheme editorTheme;
  final PageContent? page;
  final ValueChanged<ComponentBox> onSelectComponent;
  final ValueChanged<int> onCreateEntryBelow;
  final VoidCallback onTapEmptySpace;

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
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 900),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(color: editorTheme.pageBackgroundColor),
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsets.all(60),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (
                  var index = 0;
                  index < (page?.components.length ?? 0);
                  index++
                )
                  Padding(
                    key: page!.components[index].componentKey,
                    padding: const EdgeInsets.only(bottom: 6),
                    child: page!.components[index].createUI(
                      onSelect: () =>
                          onSelectComponent(page!.components[index]),
                      onCreateBelow: () => onCreateEntryBelow(index),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
