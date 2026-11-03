import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

class FileImportDialog extends StatefulWidget {
  const FileImportDialog({
    super.key,
    required this.label,
    required this.typeGroup,
    required this.description,
    required this.onImport,
  });
  final String label;
  final XTypeGroup typeGroup;
  final String description;
  final Future<void> Function(String path) onImport;

  @override
  State<FileImportDialog> createState() => _FileImportDialogState();
}

class _FileImportDialogState extends State<FileImportDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _chooseFile() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await openFile(acceptedTypeGroups: [widget.typeGroup]);
      if (!mounted) return;
      if (file == null) {
        setState(() => _busy = false);
        return;
      }
      await widget.onImport(file.path);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error =
              'Could not import this ${widget.label} file. ${error.toString().replaceFirst('FormatException: ', '')}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text('Import ${widget.label}'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.description),
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
          child: Text('Choose ${widget.label} file'),
        ),
      ],
    ),
  );
}
