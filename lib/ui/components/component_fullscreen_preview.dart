import 'package:flutter/material.dart';
import 'package:booklet/ui/components/drawing/drawing_document.dart';
import 'package:booklet/ui/components/table/table_document.dart';

/// A viewing-only route: no draft, editing controls, or save operation.
class TableFullscreenPreview extends StatelessWidget {
  const TableFullscreenPreview({super.key, required this.state});
  final TableComponentState state;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Table preview'),
      leading: IconButton(
        tooltip: 'Close preview',
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.of(context).pop(),
      ),
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TableScrollView(
          width: state.tableWidth,
          scrollVertically: true,
          child: TablePreview(state: state),
        ),
      ),
    ),
  );
}

class DrawingFullscreenPreview extends StatelessWidget {
  const DrawingFullscreenPreview({super.key, required this.state});
  final DrawingComponentState state;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Drawing preview'),
      leading: IconButton(
        tooltip: 'Close preview',
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.of(context).pop(),
      ),
    ),
    body: SafeArea(
      child: state.preview == null
          ? const Center(child: Text('No drawing to preview'))
          : LayoutBuilder(
              builder: (context, constraints) => InteractiveViewer(
                minScale: 0.5,
                maxScale: 5,
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Image.memory(state.preview!, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
    ),
  );
}
