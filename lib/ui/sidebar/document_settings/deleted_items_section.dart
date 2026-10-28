import 'package:booklet/application/editor_controller.dart';
import 'package:flutter/material.dart';

class DeletedItemsSection extends StatefulWidget {
  const DeletedItemsSection({super.key, required this.controller});
  final EditorController controller;

  @override
  State<DeletedItemsSection> createState() => _DeletedItemsSectionState();
}

class _DeletedItemsSectionState extends State<DeletedItemsSection> {
  String? _selectedId;
  EditorController get controller => widget.controller;

  @override
  void didUpdateWidget(covariant DeletedItemsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) _selectedId = null;
  }

  Future<void> _delete(BuildContext context, String id, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Permanently delete "$title"?'),
        content: const Text(
          'This removes this item and its contents from the deleted list. It cannot be restored from here afterward.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Permanently delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.permanentlyDeleteItem(id);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      controller,
      controller.documentSettingsController,
    ]),
    builder: (context, _) => _buildContent(context),
  );

  Widget _buildContent(BuildContext context) {
    final selected = controller.deletedItems
        .where((item) => item.id == _selectedId)
        .firstOrNull;
    final disabled =
        controller.trashBusy ||
        controller.snapshotsBusy ||
        controller.documentSettingsController.isReadOnly;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: ExpansionTile(
        key: const PageStorageKey<String>('deleted_items'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          'Deleted pages and groups',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        children: [
          Text(
            'Deleted items are kept for 30 days. Restored items appear at the top level with “(restored)” in their names.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (controller.trashError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                controller.trashError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (controller.deletedItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No deleted pages or groups.'),
            ),
          for (final item in controller.deletedItems) ...[
            const Divider(),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              selected: item.id == selected?.id,
              selectedTileColor: Theme.of(context)
                  .colorScheme
                  .secondaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              onTap: disabled
                  ? null
                  : () => setState(() => _selectedId = item.id),
              leading: Icon(
                item.type == 'group'
                    ? Icons.view_list_outlined
                    : item.type == 'assetsFolder'
                    ? Icons.folder_outlined
                    : Icons.notes,
                size: 18,
              ),
              title: Text(
                item.title,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              subtitle: Text(
                'Deleted ${MaterialLocalizations.of(context).formatMediumDate(item.deletedAt.toLocal())} · ${(item.expiresAt.difference(DateTime.now().toUtc()).inSeconds / 86400).ceil().clamp(0, 30)} days left',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              trailing: item.id == selected?.id
                  ? const Icon(Icons.check_circle_outline, size: 18)
                  : null,
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: disabled || selected == null
                    ? null
                    : () => controller.restoreDeletedItem(selected.id),
                child: const Text('Restore'),
              ),
              TextButton(
                onPressed: disabled || selected == null
                    ? null
                    : () => _delete(context, selected.id, selected.title),
                child: const Text('Permanently delete'),
              ),
            ],
          ),
          if (controller.trashBusy) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
