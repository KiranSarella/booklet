import 'package:booklet/application/editor_controller.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

class PdfImportDialog extends StatefulWidget {
  const PdfImportDialog({super.key, required this.controller});
  final EditorController controller;

  @override
  State<PdfImportDialog> createState() => _PdfImportDialogState();
}

class _PdfImportDialogState extends State<PdfImportDialog> {
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
            label: 'PDF',
            extensions: ['pdf'],
            uniformTypeIdentifiers: ['com.adobe.pdf'],
          ),
        ],
      );
      if (!mounted) return;
      if (file == null) {
        setState(() => _busy = false);
        return;
      }
      await widget.controller.importPdf(file.path);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error =
              'Could not import this PDF. ${error.toString().replaceFirst('FormatException: ', '')}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Import PDF'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Import editable headings, paragraphs, bold and italic text, and embedded images. Multi-page PDFs become a group with a page per detected chapter or top-level heading; original PDF pages are used when no chapters are detected. Layout and reading order are reconstructed and may need adjustment.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Scanned pages import as images; OCR is needed to edit their text. Tables and vector illustrations are not reconstructed. Unlock password-protected PDFs first. Maximum file size: 50 MB.',
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
          child: const Text('Choose PDF file'),
        ),
      ],
    ),
  );
}
