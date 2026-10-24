import 'dart:async';
import 'dart:io';

import 'package:booklet/business/booklet_asset.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class MediaSlideshowDialog extends StatefulWidget {
  const MediaSlideshowDialog({super.key, 
    required this.assets,
    required this.initialIndex,
    required this.resolvePath,
    required this.resolveThumbnailPath,
  });

  final List<BookletAsset> assets;
  final int initialIndex;
  final String Function(BookletAsset) resolvePath;
  final String? Function(BookletAsset) resolveThumbnailPath;

  @override
  State<MediaSlideshowDialog> createState() => _MediaSlideshowDialogState();
}

class _MediaSlideshowDialogState extends State<MediaSlideshowDialog> {
  late int _index = widget.initialIndex < 0 ? 0 : widget.initialIndex;
  VideoPlayerController? _player;
  bool _initialized = false;
  bool _failed = false;
  final FocusNode _focusNode = FocusNode();

  BookletAsset get _asset => widget.assets[_index];

  @override
  void initState() {
    super.initState();
    _loadVideo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _disposePlayer();
    super.dispose();
  }

  void _disposePlayer() {
    final player = _player;
    _player = null;
    if (player != null) unawaited(player.dispose());
  }

  Future<void> _loadVideo() async {
    _disposePlayer();
    _initialized = false;
    _failed = false;
    if (_asset.kind != BookletAssetKind.video) return;
    final player = VideoPlayerController.file(File(widget.resolvePath(_asset)));
    _player = player;
    try {
      await player.initialize();
      if (mounted && identical(_player, player)) {
        setState(() => _initialized = true);
      }
    } catch (_) {
      if (mounted && identical(_player, player)) setState(() => _failed = true);
    }
  }

  void _select(int index) {
    if (index < 0 || index >= widget.assets.length || index == _index) return;
    setState(() => _index = index);
    _loadVideo();
  }

  void _previous() => _select(_index - 1);
  void _next() => _select(_index + 1);

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: ColoredBox(
        color: Colors.black,
        child: SafeArea(
          child: Focus(
            focusNode: _focusNode,
            onKeyEvent: (_, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                _previous();
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                _next();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous media',
                      onPressed: _index > 0 ? _previous : null,
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                    ),
                    Expanded(
                      child: Text(
                        '${_index + 1} / ${widget.assets.length}  ·  ${_asset.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next media',
                      onPressed: _index < widget.assets.length - 1
                          ? _next
                          : null,
                      icon: const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close preview',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_asset.kind == BookletAssetKind.image)
                        InteractiveViewer(
                          key: ValueKey(_asset.id),
                          child: Center(
                            child: Image.file(
                              File(widget.resolvePath(_asset)),
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white70,
                                size: 72,
                              ),
                            ),
                          ),
                        )
                      else if (_initialized && _player != null)
                        AspectRatio(
                          aspectRatio: _player!.value.aspectRatio,
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              VideoPlayer(_player!),
                              VideoProgressIndicator(
                                _player!,
                                allowScrubbing: true,
                                padding: const EdgeInsets.all(12),
                              ),
                              Align(
                                alignment: Alignment.center,
                                child: IconButton.filledTonal(
                                  tooltip: _player!.value.isPlaying
                                      ? 'Pause'
                                      : 'Play',
                                  onPressed: () => setState(() {
                                    _player!.value.isPlaying
                                        ? _player!.pause()
                                        : _player!.play();
                                  }),
                                  icon: Icon(
                                    _player!.value.isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (_failed)
                        const Text(
                          'Could not preview this video',
                          style: TextStyle(color: Colors.white),
                        )
                      else
                        const CircularProgressIndicator(color: Colors.white),
                    ],
                  ),
                ),
                SizedBox(
                  height: 88,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: widget.assets.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final asset = widget.assets[index];
                      final selected = index == _index;
                      final thumbnailPath = widget.resolveThumbnailPath(asset);
                      return InkWell(
                        onTap: () => _select(index),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          width: 88,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: selected ? Colors.white : Colors.white24,
                              width: selected ? 3 : 1,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (thumbnailPath != null)
                                Image.file(
                                  File(thumbnailPath),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const ColoredBox(
                                    color: Colors.black54,
                                    child: Icon(
                                      Icons.broken_image,
                                      color: Colors.white70,
                                    ),
                                  ),
                                )
                              else
                                const ColoredBox(
                                  color: Colors.black54,
                                  child: Icon(
                                    Icons.image_outlined,
                                    color: Colors.white70,
                                  ),
                                ),
                              if (asset.kind == BookletAssetKind.video)
                                const Center(
                                  child: Icon(
                                    Icons.play_circle_outline,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  color: Colors.black54,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    asset.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
