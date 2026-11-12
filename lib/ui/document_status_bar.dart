import 'package:flutter/material.dart';
import 'package:booklet/ui/detail/editor/page_settings/page_settings_view.dart';
import 'package:booklet/ui/detail/editor/page_settings/page_settings_vm.dart';
import 'package:booklet/application/appearance_mode.dart';
import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';

class DocumentStatusBar extends StatelessWidget {
  const DocumentStatusBar({
    super.key,
    required this.documentPath,
    required this.pageSettingsController,
    required this.documentSettingsController,
    this.onUndo,
    this.onRedo,
    this.onScrollToTop,
    this.onScrollToBottom,
  });

  final String? documentPath;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onScrollToTop;
  final VoidCallback? onScrollToBottom;
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
              tooltip: 'Scroll to top (Alt+↑)',
              icon: Icons.vertical_align_top,
              onPressed: onScrollToTop,
            ),
            _StatusAction(
              tooltip: 'Scroll to bottom (Alt+↓)',
              icon: Icons.vertical_align_bottom,
              onPressed: onScrollToBottom,
            ),
            const SizedBox(width: 18),
            _StatusAction(tooltip: 'Undo', icon: Icons.undo, onPressed: onUndo),
            _StatusAction(tooltip: 'Redo', icon: Icons.redo, onPressed: onRedo),
            const SizedBox(width: 18),
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
            const SizedBox(width: 18),
            _StatusAction(
              tooltip: 'Page settings',
              icon: Icons.palette_outlined,
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => PageSettingsDialog(
                  viewModel: PageSettingsVM(
                    pageSettingsController: pageSettingsController,
                    documentSettingsController: documentSettingsController,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            _AppearancePicker<EditorAppearanceMode>(
              tooltip: 'Page appearance',
              modes: EditorAppearanceMode.values,
              selected: pageSettingsController.appearanceMode,
              onSelected: pageSettingsController.updateAppearanceMode,
            ),
            const SizedBox(width: 4),
            _AppearancePicker<DocumentAppearanceMode>(
              tooltip: 'Document appearance',
              modes: DocumentAppearanceMode.values,
              selected: documentSettingsController.appearanceMode,
              onSelected: documentSettingsController.updateAppearanceMode,
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
  final VoidCallback? onPressed;

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

class _AppearancePicker<T extends Enum> extends StatelessWidget {
  const _AppearancePicker({
    required this.tooltip,
    required this.modes,
    required this.selected,
    required this.onSelected,
  });

  final String tooltip;
  final List<T> modes;
  final T selected;
  final ValueChanged<T> onSelected;

  static const _icons = [
    Icons.light_mode_outlined,
    Icons.dark_mode_outlined,
    Icons.brightness_auto_outlined,
  ];
  static const _labels = ['Light', 'Dark', 'Auto'];

  @override
  Widget build(BuildContext context) => MenuAnchor(
    style: const MenuStyle(alignment: Alignment.topCenter),
    menuChildren: [
      for (final mode in modes)
        MenuItemButton(
          leadingIcon: Icon(_icons[mode.index], size: 18),
          trailingIcon: mode == selected
              ? const Icon(Icons.check, size: 16)
              : null,
          onPressed: () => onSelected(mode),
          child: Text(_labels[mode.index]),
        ),
    ],
    builder: (context, controller, child) => _StatusAction(
      tooltip: '$tooltip: ${_labels[selected.index]}',
      icon: _icons[selected.index],
      onPressed: () {
        if (controller.isOpen) {
          controller.close();
        } else {
          controller.open();
        }
      },
    ),
  );
}
