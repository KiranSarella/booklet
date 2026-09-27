import 'package:booklet/business/page_content.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/application/page_settings_controller.dart';
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

  final PageSettingsController editorTheme;
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
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: 900,
              maxWidth: editorTheme.maxContentWidth ?? double.infinity,
            ),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: editorTheme.pageBackgroundColor,
              ),
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
                      child: page!.components[index].buildUI(
                        theme: editorTheme,
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
      ),
    );
  }
}
