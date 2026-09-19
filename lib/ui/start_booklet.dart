import 'package:flutter/material.dart';

class StartBooklet extends StatelessWidget {
  const StartBooklet({
    super.key,
    required this.onCreateNew,
    required this.onOpenExisting,
  });

  final VoidCallback onCreateNew;
  final Future<void> Function() onOpenExisting;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Positioned.fill(
      child: ColoredBox(
        color: colorScheme.surface,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(24),
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
                    onPressed: onCreateNew,
                    icon: const Icon(Icons.add),
                    label: const Text('Create new'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: onOpenExisting,
                    icon: const Icon(Icons.folder_open_outlined),
                    label: const Text('Open existing'),
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
