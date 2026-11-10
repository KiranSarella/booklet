import 'package:booklet/application/recent_booklets.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';

class StartBooklet extends StatefulWidget {
  const StartBooklet({
    super.key,
    required this.onCreateNew,
    required this.onOpenExisting,
    this.onOpenLegacy,
    required this.onOpenRecent,
  });

  final Future<void> Function()? onOpenLegacy;
  final VoidCallback onCreateNew;
  final Future<void> Function() onOpenExisting;

  final Future<void> Function(String path) onOpenRecent;

  @override
  State<StartBooklet> createState() => _StartBookletState();
}

class _StartBookletState extends State<StartBooklet> {
  late Future<List<String>> _recents = RecentBooklets.load();
  bool _opening = false;
  String? _hoveredPath;

  Future<void> _removeRecent(String path) async {
    setState(() => _opening = true);
    try {
      await RecentBooklets.remove(path);
      final paths = await RecentBooklets.load();
      if (mounted) setState(() => _recents = Future.value(paths));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not remove recent booklet.')),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _openRecent(String path) async {
    setState(() => _opening = true);
    try {
      await widget.onOpenRecent(path);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Positioned.fill(
      child: Material(
        color: colorScheme.surface,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Start booklet',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Open an existing booklet or create a new one.',
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: _opening ? null : widget.onCreateNew,
                      icon: const Icon(Icons.add),
                      label: const Text('Create new'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _opening ? null : widget.onOpenExisting,
                      icon: const Icon(Icons.folder_open_outlined),
                      label: const Text('Open existing'),
                    ),
                    if (widget.onOpenLegacy != null)
                      TextButton(
                        onPressed: _opening ? null : widget.onOpenLegacy,
                        child: const Text('Open older folder package…'),
                      ),
                    const SizedBox(height: 24),
                    Text(
                      'Recents',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<List<String>>(
                      future: _recents,
                      builder: (context, snapshot) {
                        final paths = snapshot.data ?? <String>[];
                        if (paths.isEmpty) {
                          return const Text('No recent booklets yet.');
                        }
                        return Column(
                          children: [
                            for (final path in paths)
                              MouseRegion(
                                onEnter: (_) =>
                                    setState(() => _hoveredPath = path),
                                onExit: (_) => setState(() {
                                  if (_hoveredPath == path) _hoveredPath = null;
                                }),
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.menu_book_outlined),
                                  title: Text(p.basename(path)),
                                  subtitle: Text(path),
                                  trailing: Visibility(
                                    visible: _hoveredPath == path,
                                    maintainSize: true,
                                    maintainAnimation: true,
                                    maintainState: true,
                                    child: IconButton(
                                      tooltip: 'Remove from recents',
                                      icon: const Icon(Icons.close),
                                      onPressed: _opening
                                          ? null
                                          : () => _removeRecent(path),
                                    ),
                                  ),
                                  enabled: !_opening,
                                  onTap: () => _openRecent(path),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
