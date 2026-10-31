import 'package:booklet/ui/components/table/table_document.dart';
import 'package:booklet/ui/components/drawing/drawing_document.dart';

import 'dart:io';
import 'dart:math' as math;

import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// A passive miniature of a component; never mounts an editable component.
class ComponentMinimapPreview extends StatelessWidget {
  const ComponentMinimapPreview({super.key, required this.box});

  final ComponentBox box;

  @override
  Widget build(BuildContext context) {
    final state = box.component.state;
    final kind = box.component.def.key;
    final colors = Theme.of(context).colorScheme;
    final text = state is TextComponentState
        ? state.controller.document.toPlainText().trim()
        : '';
    Widget preview;
    if (['title', 'heading', 'subheading', 'inline_heading'].contains(kind)) {
      preview = Align(
        alignment: kind == 'title' ? Alignment.center : Alignment.centerLeft,
        child: LayoutBuilder(
          builder: (context, constraints) => FittedBox(
            fit: BoxFit.scaleDown,
            alignment: kind == 'title'
                ? Alignment.center
                : Alignment.centerLeft,
            child: SizedBox(
              width: constraints.maxWidth,
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: kind == 'title' ? TextAlign.center : TextAlign.start,
                style: TextStyle(
                  fontSize: switch (kind) {
                    'title' => 14,
                    'heading' => 12,
                    _ => 11,
                  },
                  height: 1,
                  fontWeight: kind == 'inline_heading'
                      ? FontWeight.w600
                      : FontWeight.w800,
                  color: colors.onSurface,
                ),
              ),
            ),
          ),
        ),
      );
    } else if (state is TableComponentState) {
      preview = const Icon(Icons.table_chart_outlined);
    } else if (state is DrawingComponentState) {
      preview = state.preview == null
          ? const Icon(Icons.draw_outlined)
          : Image.memory(state.preview!, fit: BoxFit.contain);
    } else if (state is ImageComponentState) {
      preview = _image(state.mediaPath, Icons.image_outlined);
    } else if (state is VideoComponentState) {
      preview = _VideoMiniature(path: state.mediaPath);
    } else if ([
      'math',
      'code_block',
      'assets',
      'audio',
      'embed',
    ].contains(kind)) {
      preview = DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
          border: Border.all(color: colors.outlineVariant, width: 0.6),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Icon(
              switch (kind) {
                'math' => Icons.functions,
                'code_block' => Icons.code,
                'audio' => Icons.music_note,
                'embed' => Icons.integration_instructions_outlined,
                _ => Icons.folder_outlined,
              },
              size: 15,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      );
    } else {
      final marker = switch (state) {
        BulletedListComponentState() => state.symbol,
        NumberedListComponentState() => state.formatNumber(
          state.sequenceNumber,
        ),
        ChecklistComponentState() => state.isChecked ? '☑' : '☐',
        QuoteComponentState() => '“',
        _ => '',
      };
      preview = CustomPaint(
        painter: _MiniatureLines(
          color: colors.onSurfaceVariant.withValues(alpha: 0.16),
          markerColor: colors.onSurfaceVariant,
          marker: marker,
          textLength: text.length,
          nesting: state is ListItemComponentState ? state.nestingLevel : 0,
        ),
      );
    }
    return ClipRect(
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: box.hasFocusBar
              ? Border(left: BorderSide(color: colors.primary, width: 2))
              : null,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: box.hasFocusBar ? 5 : 0,
            top: 1,
            bottom: 1,
          ),
          child: preview,
        ),
      ),
    );
  }
}

Widget _image(String? path, IconData fallback) {
  Widget placeholder() => Center(
    child: FittedBox(fit: BoxFit.scaleDown, child: Icon(fallback, size: 16)),
  );
  if (path == null || path.isEmpty) return placeholder();
  final uri = Uri.tryParse(path);
  if (uri?.scheme == 'https' || uri?.scheme == 'http') {
    return Image.network(
      path,
      fit: BoxFit.contain,
      cacheWidth: 180,
      errorBuilder: (_, _, _) => placeholder(),
    );
  }
  return Image.file(
    File(path),
    fit: BoxFit.contain,
    cacheWidth: 180,
    errorBuilder: (_, _, _) => placeholder(),
  );
}

class _VideoMiniature extends StatefulWidget {
  const _VideoMiniature({required this.path});
  final String? path;

  @override
  State<_VideoMiniature> createState() => _VideoMiniatureState();
}

class _VideoMiniatureState extends State<_VideoMiniature> {
  late Future<Uint8List?> _thumbnail;

  @override
  void initState() {
    super.initState();
    _thumbnail = _loadThumbnail(widget.path);
  }

  @override
  void didUpdateWidget(_VideoMiniature oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _thumbnail = _loadThumbnail(widget.path);
  }

  Future<Uint8List?> _loadThumbnail(String? path) async {
    if (path == null || path.isEmpty) return null;
    Directory? temporary;
    try {
      if (Platform.isMacOS) {
        temporary = await Directory.systemTemp.createTemp('booklet_minimap_');
        final thumbnail = File('${temporary.path}/preview.png');
        await const MethodChannel('booklet/video_thumbnail').invokeMethod<bool>(
          'createVideoThumbnail',
          {'videoPath': path, 'thumbnailPath': thumbnail.path},
        );
        if (await thumbnail.exists()) return await thumbnail.readAsBytes();
        return null;
      }
      return await VideoThumbnail.thumbnailData(
        video: path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 180,
        quality: 65,
      );
    } catch (_) {
      // Missing or unsupported media still retains its video/play silhouette.
      return null;
    } finally {
      if (temporary != null) await temporary.delete(recursive: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _thumbnail,
      builder: (context, snapshot) => Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          if (snapshot.data != null)
            Image.memory(
              snapshot.data!,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          const Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Icon(
                Icons.play_circle_fill,
                size: 18,
                color: Colors.white,
                shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniatureLines extends CustomPainter {
  const _MiniatureLines({
    required this.color,
    required this.markerColor,
    required this.marker,
    required this.textLength,
    required this.nesting,
  });
  final Color color;
  final Color markerColor;
  final String marker;
  final int textLength;
  final int nesting;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final indent = (nesting * 5.0).clamp(0.0, size.width / 3);
    var left = indent;
    final quote = marker == '“';
    var right = 0.0;
    if (marker.isNotEmpty) {
      final painter = TextPainter(
        text: TextSpan(
          text: quote
              ? String.fromCharCode(Icons.format_quote_rounded.codePoint)
              : marker,
          style: TextStyle(
            color: markerColor,
            fontSize: quote ? 14 : 8,
            fontFamily: quote ? Icons.format_quote_rounded.fontFamily : null,
            height: 1,
            fontWeight: quote ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final markerScale = math.min(1.0, size.height / painter.height);
      canvas.save();
      canvas.scale(markerScale);
      final markerWidth = painter.width * markerScale;
      if (quote) {
        canvas.save();
        canvas.translate(
          left / markerScale + painter.width / 2,
          painter.height / 2,
        );
        canvas.rotate(math.pi);
        painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
        canvas.restore();
        painter.paint(
          canvas,
          Offset(
            (size.width - markerWidth) / markerScale,
            math.max(0, size.height / markerScale - painter.height),
          ),
        );
        right = markerWidth + 3;
      } else {
        painter.paint(canvas, Offset(left / markerScale, 0));
      }
      canvas.restore();
      left += markerWidth + 3;
      painter.dispose();
    }
    final width = (size.width - left - right).clamp(0.0, size.width);
    final count = (size.height / 4).ceil().clamp(1, 50);
    final paint = Paint()..color = color;
    for (var i = 0; i < count; i++) {
      final fraction = i == count - 1 ? 0.35 + (textLength % 45) / 100 : 1.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, i * 4 + 2, width * fraction, 1.2),
          const Radius.circular(0.6),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MiniatureLines oldDelegate) =>
      color != oldDelegate.color ||
      markerColor != oldDelegate.markerColor ||
      marker != oldDelegate.marker ||
      textLength != oldDelegate.textLength ||
      nesting != oldDelegate.nesting;
}
