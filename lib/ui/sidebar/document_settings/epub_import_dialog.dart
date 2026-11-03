import 'package:booklet/application/editor_controller.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

class EpubImportDialog extends StatefulWidget {
  const EpubImportDialog({super.key, required this.controller});
  final EditorController controller;

  @override
  State<EpubImportDialog> createState() => _EpubImportDialogState();
}

class _EpubImportDialogState extends State<EpubImportDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _chooseFile() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'EPUB',
            extensions: ['epub'],
            uniformTypeIdentifiers: ['org.idpf.epub-container'],
          ),
        ],
      );
      if (!mounted) return;
      if (file == null) {
        setState(() => _busy = false);
        return;
      }
      await widget.controller.importEpub(file.path);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error =
              'Could not import this EPUB. ${error.toString().replaceFirst('FormatException: ', '')}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Import EPUB'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Import an EPUB book as editable chapters with headings, text, links, and embedded images. Chapter order follows the book’s reading order.',
            ),
            const SizedBox(height: 12),
            const Text(
              'DRM-protected books are not supported. Publisher styling and complex layouts may need adjustment. Maximum file size: 50 MB.',
            ),
            if (_busy) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _chooseFile,
          child: const Text('Choose EPUB file'),
        ),
      ],
    ),
  );
}
