import 'package:booklet/application/editor_controller.dart';
import 'package:flutter/material.dart';

class DocumentToolbar extends StatefulWidget {
  const DocumentToolbar({
    super.key,
    required this.controller,
    required this.onOpenInNewWindow,
  });

  final EditorController controller;
  final VoidCallback onOpenInNewWindow;

  @override
  State<DocumentToolbar> createState() => DocumentToolbarState();
}

class DocumentToolbarState extends State<DocumentToolbar> {
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
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _ActionButton(
            tooltip: 'Open booklet',
            icon: Icons.folder_open_outlined,
            onPressed: openBooklet,
          ),
          _ActionButton(
            tooltip: 'Save booklet',
            icon: Icons.save_outlined,
            onPressed: saveBooklet,
          ),
          _ActionButton(
            tooltip: 'Open in new window',
            icon: Icons.open_in_new,
            onPressed: widget.onOpenInNewWindow,
          ),
          if (widget.controller.isAutoSaving)
            const Tooltip(
              message: 'Saving changes',
              child: SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (widget.controller.autoSaveError != null)
            Tooltip(
              message: 'Auto-save failed: ${widget.controller.autoSaveError}',
              child: Icon(
                Icons.cloud_off_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
        ],
      ),
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
