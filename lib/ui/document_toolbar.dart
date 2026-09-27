import 'package:booklet/application/editor_controller.dart';
import 'package:booklet/ui/document_settings/document_settings_view.dart';
import 'package:booklet/ui/document_settings/document_settings_vm.dart';
import 'package:flutter/material.dart';

class DocumentToolbar extends StatefulWidget {
  const DocumentToolbar({
    super.key,
    required this.controller,
    required this.onEditTheme,
  });

  final EditorController controller;
  final VoidCallback onEditTheme;

  @override
  State<DocumentToolbar> createState() => DocumentToolbarState();
}

class DocumentToolbarState extends State<DocumentToolbar> {
  void _showDocumentSettings() {
    showDialog<void>(
      context: context,
      builder: (context) => DocumentSettingsDialog(
        viewModel: DocumentSettingsVM(
          settingsController: widget.controller.documentSettingsController,
          editorTheme: widget.controller.editorTheme,
        ),
      ),
    );
  }

  Future<void> saveBooklet() async {
    if (!widget.controller.hasOpenedBooklet) {
      _showMessage('Opening save dialog...');
    }
    try {
      final saved = await widget.controller.saveBooklet();
      if (saved) {
        _showMessage('Booklet saved');
      }
    } catch (error) {
      _showMessage('Could not save booklet: $error');
    }
  }

  Future<void> openBooklet() async {
    _showMessage('Opening file dialog...');
    try {
      final opened = await widget.controller.openBooklet();
      if (opened) {
        _showMessage('Booklet opened');
      }
    } catch (error) {
      _showMessage('Could not open booklet: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          tooltip: 'Open booklet',
          icon: Icons.folder_open_outlined,
          onPressed: openBooklet,
        ),
        const SizedBox(width: 8),
        _ActionButton(
          tooltip: 'Save booklet',
          icon: Icons.save_outlined,
          onPressed: saveBooklet,
        ),
        const SizedBox(width: 8),
        _ActionButton(
          tooltip: 'Edit theme',
          icon: Icons.palette_outlined,
          onPressed: widget.onEditTheme,
        ),
        const SizedBox(width: 8),
        _ActionButton(
          tooltip: 'Document settings',
          icon: Icons.settings_outlined,
          onPressed: _showDocumentSettings,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          constraints: const BoxConstraints.tightFor(width: 52, height: 44),
          padding: EdgeInsets.zero,
          tooltip: tooltip,
        ),
      ),
    );
  }
}
