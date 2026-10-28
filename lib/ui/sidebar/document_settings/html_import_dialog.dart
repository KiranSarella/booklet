import 'package:booklet/application/editor_controller.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

class HtmlImportDialog extends StatefulWidget {
  const HtmlImportDialog({super.key, required this.controller});
  final EditorController controller;

  @override
  State<HtmlImportDialog> createState() => _HtmlImportDialogState();
}

class _HtmlImportDialogState extends State<HtmlImportDialog> {
  final _url = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _import(Uri source) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.importHtml(source);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error =
              'Could not import this page. ${error.toString().replaceFirst('FormatException: ', '')}';
        });
      }
    }
  }

  void _importUrl() {
    final uri = Uri.tryParse(_url.text.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      setState(
        () => _error =
            'Enter an http:// or https:// URL, including localhost URLs.',
      );
      return;
    }
    _import(uri);
  }

  Future<void> _chooseFile() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'HTML', extensions: ['html', 'htm']),
        ],
      );
      if (file != null && mounted) await _import(Uri.file(file.path));
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not open this file. $error');
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Import HTML'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Import page content into a new editable page. Images and media remain linked to their source.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _url,
              enabled: !_busy,
              autofocus: true,
              keyboardType: TextInputType.url,
              onSubmitted: (_) {
                if (!_busy) _importUrl();
              },
              decoration: const InputDecoration(
                labelText: 'Website URL',
                hintText: 'https://example.com/article',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _chooseFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('Choose HTML file'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Works with static articles and documentation. Pages requiring JavaScript or sign-in may not import.',
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
          onPressed: _busy ? null : _importUrl,
          child: const Text('Import URL'),
        ),
      ],
    ),
  );
}
