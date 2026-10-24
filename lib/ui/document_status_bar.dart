import 'package:flutter/material.dart';
import 'package:booklet/application/appearance_mode.dart';
import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';

class DocumentStatusBar extends StatelessWidget {
  const DocumentStatusBar({
    super.key,
    required this.documentPath,
    required this.pageSettingsController,
    required this.documentSettingsController,
  });

  final String? documentPath;
  final PageSettingsController pageSettingsController;
  final DocumentSettingsController documentSettingsController;

  @override
  Widget build(BuildContext context) {
    final fileName = documentPath?.split(RegExp(r'[/\\]')).last;
    final colors = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([
        pageSettingsController,
        documentSettingsController,
      ]),
      builder: (context, _) => Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          border: Border(top: BorderSide(color: colors.outlineVariant)),
        ),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Expanded(
              child: Text(
                fileName == null || fileName.isEmpty
                    ? 'Untitled booklet'
                    : fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
            _StatusAction(
              tooltip: 'Decrease page font size',
              icon: Icons.remove,
              onPressed: pageSettingsController.decreaseFontSize,
            ),
            _StatusAction(
              tooltip: 'Reset page font size',
              icon: Icons.format_size,
              onPressed: () => pageSettingsController.resetFontSize(),
            ),
            _StatusAction(
              tooltip: 'Increase page font size',
              icon: Icons.add,
              onPressed: pageSettingsController.increaseFontSize,
            ),
            const SizedBox(width: 8),
            _StatusAction(
              tooltip: 'Switch page appearance',
              icon:
                  pageSettingsController.effectiveBrightness == Brightness.light
                  ? Icons.dark_mode_outlined
                  : Icons.light_mode_outlined,
              onPressed: () => pageSettingsController.updateAppearanceMode(
                pageSettingsController.effectiveBrightness == Brightness.light
                    ? EditorAppearanceMode.dark
                    : EditorAppearanceMode.light,
              ),
            ),
            const SizedBox(width: 8),
            _StatusAction(
              tooltip: 'Switch document appearance',
              icon:
                  documentSettingsController.effectiveBrightness ==
                      Brightness.light
                  ? Icons.dark_mode_outlined
                  : Icons.light_mode_outlined,
              onPressed: () => documentSettingsController.updateAppearanceMode(
                documentSettingsController.effectiveBrightness ==
                        Brightness.light
                    ? DocumentAppearanceMode.dark
                    : DocumentAppearanceMode.light,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusAction extends StatelessWidget {
  const _StatusAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
    ),
  );
}
