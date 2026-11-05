import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'online_video.dart';

/// Source actions belong outside the media preview, above its caption.
class MediaSourceLink extends StatelessWidget {
  const MediaSourceLink({super.key, required this.url});

  final String url;

  Future<void> _open(BuildContext context) async {
    try {
      if (await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {
      // Leave the selectable source available if launching fails.
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open browser. Copy the link above.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = OnlineVideo.parse(url)?.label;
    final style = TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 12,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final source = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (label != null) Text(label, style: style),
                SelectableText(url, maxLines: 2, style: style),
              ],
            );
            final button = TextButton.icon(
              onPressed: () => _open(context),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open in browser'),
            );
            if (constraints.maxWidth < 420) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [source, button],
              );
            }
            return Row(
              children: [
                Expanded(child: source),
                const SizedBox(width: 12),
                button,
              ],
            );
          },
        ),
      ),
    );
  }
}
