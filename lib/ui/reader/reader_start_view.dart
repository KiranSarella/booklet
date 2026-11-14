import 'package:flutter/material.dart';
import 'package:booklet/application/recent_booklets.dart';

class ReaderStartView extends StatefulWidget {
  const ReaderStartView({
    super.key,
    required this.onOpen,
    required this.onOpenRecent,
    required this.busy,
  });
  final VoidCallback onOpen;
  final ValueChanged<String> onOpenRecent;
  final bool busy;

  @override
  State<ReaderStartView> createState() => _ReaderStartViewState();
}

class _ReaderStartViewState extends State<ReaderStartView> {
  late Future<List<RecentBooklet>> _recents = RecentBooklets.loadEntries();
  bool _removing = false;

  Future<void> _remove(String path) async {
    setState(() => _removing = true);
    try {
      await RecentBooklets.remove(path);
      final entries = await RecentBooklets.loadEntries();
      if (mounted) setState(() => _recents = Future.value(entries));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not remove recent booklet.')),
        );
      }
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = widget.busy || _removing;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.auto_stories_outlined, size: 64),
              const SizedBox(height: 24),
              Text(
                'Your booklets, ready to read',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Open a .booklet file.\nDocuments open in read-only mode.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: busy ? null : widget.onOpen,
                icon: const Icon(Icons.folder_open),
                label: const Text('Open booklet'),
              ),
              const SizedBox(height: 32),
              Text('Recents', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              FutureBuilder<List<RecentBooklet>>(
                future: _recents,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text('Could not load recent booklets.');
                  }
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  final entries = snapshot.data!;
                  if (entries.isEmpty) {
                    return const Text('No recent booklets yet.');
                  }
                  return Column(
                    children: [
                      for (final entry in entries)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.menu_book_outlined),
                          title: Text(
                            entry.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            tooltip: 'Remove from recents',
                            icon: const Icon(Icons.close),
                            onPressed: busy ? null : () => _remove(entry.path),
                          ),
                          enabled: !busy,
                          onTap: () => widget.onOpenRecent(entry.path),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
