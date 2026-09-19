import 'package:booklet/ui/base_view.dart';
import 'package:flutter/material.dart';

class DocumentToolbar extends StatefulWidget {
  const DocumentToolbar({
    super.key,
    required this.editorKey,
    required this.onEditTheme,
  });

  final GlobalKey<BaseViewState> editorKey;
  final VoidCallback onEditTheme;

  @override
  State<DocumentToolbar> createState() => DocumentToolbarState();
}

class DocumentToolbarState extends State<DocumentToolbar> {
  Future<void> saveBooklet() async {
    final editor = widget.editorKey.currentState;
    if (editor == null) {
      return;
    }
    if (!editor.hasOpenedBooklet) {
      _showMessage('Opening save dialog...');
    }
    try {
      final saved = await editor.saveBooklet();
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
      final opened =
          await widget.editorKey.currentState?.openBooklet() ?? false;
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
