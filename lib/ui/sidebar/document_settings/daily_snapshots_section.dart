import 'package:booklet/application/editor_controller.dart';
import 'package:flutter/material.dart';

class DailySnapshotsSection extends StatelessWidget {
  const DailySnapshotsSection({super.key, required this.controller});
  final EditorController controller;

  String _size(int bytes) => bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(0)} KB'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  Future<void> _delete(BuildContext context, {String? day}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          day == null
              ? 'Clear all daily snapshots?'
              : 'Delete snapshot from $day?',
        ),
        content: const Text(
          'This frees storage. Deleted snapshots cannot be restored. Your current booklet is kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (day == null) {
      await controller.clearDailySnapshots();
    } else {
      await controller.deleteDailySnapshot(day);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = controller.snapshotsBusy;
    final examining = controller.examiningSnapshot;
    final entries = controller.dailySnapshots;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text('Daily snapshots', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(
          controller.snapshotPackage == null
              ? 'Save this booklet to enable daily snapshots.'
              : 'Keeps the last saved version from each previous active day. Up to 6 days, including media.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (controller.snapshotError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              controller.snapshotError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (examining) ...[
          const SizedBox(height: 12),
          const Text('Restored copy open. Your original is safe.'),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: busy || controller.documentSettingsController.isReadOnly
                ? null
                : controller.keepRestoredChanges,
            child: const Text('Keep this version'),
          ),
          TextButton(
            onPressed: busy ? null : controller.discardRestoredChanges,
            child: const Text('Discard restored changes'),
          ),
        ],
        if (entries.isEmpty && controller.snapshotPackage != null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No daily snapshots yet.'),
          ),
        for (final snapshot in entries) ...[
          const Divider(),
          Text(snapshot.day, style: Theme.of(context).textTheme.labelLarge),
          Text(
            _size(snapshot.bytes),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (controller.restoredSnapshotDay == snapshot.day)
            const Chip(
              avatar: Icon(Icons.restore, size: 16),
              label: Text('Restored · examining'),
            )
          else if (controller.lastRestoredSnapshotDay == snapshot.day)
            const Chip(
              avatar: Icon(Icons.check_circle_outline, size: 16),
              label: Text('Restored'),
            ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed:
                    busy ||
                        examining ||
                        controller.documentSettingsController.isReadOnly
                    ? null
                    : () => controller.restoreDailySnapshot(snapshot.day),
                child: const Text('Restore'),
              ),
              IconButton(
                tooltip: 'Delete snapshot',
                icon: const Icon(Icons.delete_outline),
                onPressed: busy || examining
                    ? null
                    : () => _delete(context, day: snapshot.day),
              ),
            ],
          ),
        ],
        if (entries.isNotEmpty) ...[
          Text(
            '${_size(entries.fold<int>(0, (total, entry) => total + entry.bytes))} stored',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          TextButton(
            onPressed: busy || examining ? null : () => _delete(context),
            child: const Text('Clear all snapshots'),
          ),
        ],
        if (busy) const LinearProgressIndicator(),
      ],
    );
  }
}
