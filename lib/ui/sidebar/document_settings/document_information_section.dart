import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:booklet/application/editor_controller.dart';
import 'package:booklet/ui/sidebar/pages_navigation/navigation_node.dart';
import 'package:flutter/material.dart';

class DocumentInformationSection extends StatefulWidget {
  const DocumentInformationSection({super.key, required this.controller});

  final EditorController controller;

  @override
  State<DocumentInformationSection> createState() =>
      _DocumentInformationSectionState();
}

class _DocumentInformationSectionState
    extends State<DocumentInformationSection> {
  Timer? _refreshTimer;
  String? _path;
  DateTime _fallbackCreated = DateTime.now();
  late Future<({DateTime? created, DateTime updated, int bytes})?> _information;

  @override
  void initState() {
    super.initState();
    _path = widget.controller.documentPath;
    _information = _load();
  }

  @override
  void didUpdateWidget(covariant DocumentInformationSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_path != widget.controller.documentPath) {
      _path = widget.controller.documentPath;
      _fallbackCreated = DateTime.now();
      _information = _load();
    }
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _information = _load());
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<({DateTime? created, DateTime updated, int bytes})?> _load() async {
    final path = widget.controller.documentPath;
    if (path == null) return null;
    final manifest = File('$path/content.json');
    final data = jsonDecode(await manifest.readAsString()) as Map;
    var bytes = 0;
    var updated = (await manifest.stat()).modified;
    // The size includes snapshots and deleted items, matching storage on disk.
    await for (final entity in Directory(
      path,
    ).list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final stat = await entity.stat();
      bytes += stat.size;
      final relative = entity.path.substring(path.length + 1);
      if (!relative.startsWith('.daily_snapshots/') &&
          !relative.startsWith('.deleted_items/') &&
          stat.modified.isAfter(updated)) {
        updated = stat.modified;
      }
    }
    return (
      created:
          DateTime.tryParse(data['createdAt'] as String? ?? '') ??
          _fallbackCreated,
      updated: updated,
      bytes: bytes,
    );
  }

  String _date(BuildContext context, DateTime date) {
    final local = date.toLocal();
    final strings = MaterialLocalizations.of(context);
    return '${strings.formatMediumDate(local)} · ${strings.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';
  }

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Widget _field(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        // Keep text scroll offsets separate from the tile's expansion state.
        SelectableText(
          value,
          key: PageStorageKey<String>('document_information_$label'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    var pages = 0;
    var groups = 0;
    var assets = 0;
    void count(Iterable<NavigationNode> nodes) {
      for (final node in nodes) {
        if (node.isPage) pages++;
        if (node.isGroup) groups++;
        assets += node.assets.length;
        count(node.children);
      }
    }

    count(widget.controller.viewModel.navigation.groups);
    final path = widget.controller.documentPath;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: ExpansionTile(
        key: const PageStorageKey<String>('document_information'),
        initiallyExpanded: true,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          'Document Information',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        children: [
          FutureBuilder<({DateTime? created, DateTime updated, int bytes})?>(
            key: ValueKey(path),
            future: _information,
            builder: (context, snapshot) {
              final info = snapshot.data;
              final fallback = path == null
                  ? 'Not saved yet'
                  : snapshot.hasError
                  ? 'Unavailable'
                  : 'Loading…';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _field(
                    context,
                    'Created date',
                    info == null
                        ? fallback
                        : info.created == null
                        ? 'Not recorded'
                        : _date(context, info.created!),
                  ),
                  _field(
                    context,
                    'Last saved date',
                    info == null ? fallback : _date(context, info.updated),
                  ),
                  _field(
                    context,
                    'Document size on disk',
                    info == null ? fallback : _size(info.bytes),
                  ),
                ],
              );
            },
          ),
          Text(
            'Size includes media, daily snapshots, and deleted items.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          _field(context, 'Pages', '$pages'),
          _field(context, 'Groups', '$groups'),
          _field(context, 'Attachments', '$assets'),
          _field(context, 'File location', path ?? 'Not saved yet'),
        ],
      ),
    );
  }
}
