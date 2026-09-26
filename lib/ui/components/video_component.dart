import 'dart:io';

import 'package:booklet/business/components_business/component_def.dart';
import 'package:booklet/business/components_business/inbuilt_components/inbuit_components_definations.dart';
import 'package:booklet/ui/components/component.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/editor_themes/editor_themes.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoComponent implements Component {
  VideoComponent({required this.id, String? mediaPath})
    : state = VideoComponentState(mediaPath: mediaPath);

  @override
  final String id;

  @override
  final VideoComponentState state;

  @override
  ComponentDef get def => VideoComponentDef();

  @override
  Object? get output => state.output;

  @override
  List<dynamic>? get textDelta => state.textDelta;

  @override
  void initialize({List<dynamic>? delta}) {}

  @override
  void dispose() => state.dispose();

  @override
  Widget buildUI({
    required EditorTheme theme,
    required ComponentState componentState,
    required bool isSelected,
    required VoidCallback onSelect,
    required VoidCallback onCreateBelow,
  }) {
    return VideoComponentView(
      state: state,
      isSelected: isSelected,
      onSelect: onSelect,
    );
  }
}

class VideoComponentView extends StatefulWidget {
  const VideoComponentView({
    super.key,
    required this.state,
    required this.isSelected,
    required this.onSelect,
  });

  final VideoComponentState state;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  State<VideoComponentView> createState() => _VideoComponentViewState();
}

class _VideoComponentViewState extends State<VideoComponentView> {
  static const _videoExtensions = <String>[
    'mp4',
    'mov',
    'm4v',
    'webm',
    'mkv',
    'avi',
  ];

  VideoPlayerController? _controller;
  String? _loadedPath;
  Object? _loadError;
  int _loadGeneration = 0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _loadedPath = widget.state.mediaPath;
    _loadVideo(_loadedPath);
  }

  @override
  void didUpdateWidget(covariant VideoComponentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.mediaPath != widget.state.mediaPath) {
      _loadedPath = widget.state.mediaPath;
      _loadVideo(_loadedPath);
    }
  }

  Future<void> _loadVideo(String? path) async {
    final generation = ++_loadGeneration;
    final previousController = _controller;
    _controller = null;
    _loadError = null;
    await previousController?.dispose();

    if (path == null || path.isEmpty) {
      if (mounted && generation == _loadGeneration) {
        setState(() {});
      }
      return;
    }

    final uri = Uri.tryParse(path);
    final isRemote =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    final controller = isRemote
        ? VideoPlayerController.networkUrl(uri)
        : VideoPlayerController.file(File(path));
    _controller = controller;

    try {
      await controller.initialize();
      if (!mounted || generation != _loadGeneration) {
        await controller.dispose();
        return;
      }
      setState(() {});
    } catch (error) {
      if (!mounted || generation != _loadGeneration) {
        await controller.dispose();
        return;
      }
      _loadError = error;
      setState(() {});
    }
  }

  Future<void> _chooseVideo() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Videos',
          extensions: _videoExtensions,
          mimeTypes: ['video/*'],
        ),
      ],
    );
    if (file != null) {
      _setVideo(file.path);
    }
  }

  void _setVideo(String path) {
    if (path.isEmpty || !_isVideoPath(path)) {
      return;
    }
    setState(() {
      widget.state.mediaPath = path;
      _loadedPath = path;
    });
    _loadVideo(path);
    widget.onSelect();
  }

  bool _isVideoPath(String path) {
    final extension = path.split('.').last.toLowerCase();
    return _videoExtensions.contains(extension);
  }

  void _showPreview(VideoPlayerController controller) {
    showDialog<void>(
      context: context,
      barrierColor: const Color.fromARGB(123, 0, 0, 0),
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: _FullscreenVideoPreview(controller: controller),
      ),
    );
  }

  @override
  void dispose() {
    _loadGeneration++;
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.state.mediaPath;
    final controller = _controller;
    final colorScheme = Theme.of(context).colorScheme;

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (detail) {
        setState(() => _isDragging = false);
        for (final file in detail.files) {
          if (_isVideoPath(file.path)) {
            _setVideo(file.path);
            break;
          }
        }
      },
      child: GestureDetector(
        onTap: widget.onSelect,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          child: path == null || path.isEmpty
              ? _EmptyVideoState(
                  isDragging: _isDragging,
                  onChooseVideo: _chooseVideo,
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        border: widget.isSelected
                            ? Border.all(color: colorScheme.primary, width: 2)
                            : null,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _loadError != null
                          ? const _VideoUnavailable()
                          : controller == null ||
                                !controller.value.isInitialized
                          ? const AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AspectRatio(
                                  aspectRatio: controller.value.aspectRatio > 0
                                      ? controller.value.aspectRatio
                                      : 16 / 9,
                                  child: VideoPlayer(controller),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      tooltip: controller.value.isPlaying
                                          ? 'Pause video'
                                          : 'Play video',
                                      onPressed: () {
                                        setState(() {
                                          controller.value.isPlaying
                                              ? controller.pause()
                                              : controller.play();
                                        });
                                      },
                                      color: Colors.white,
                                      icon: Icon(
                                        controller.value.isPlaying
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                      ),
                                    ),
                                    Expanded(
                                      child: VideoProgressIndicator(
                                        controller,
                                        allowScrubbing: true,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        colors: VideoProgressColors(
                                          playedColor: colorScheme.primary,
                                          bufferedColor: Colors.white38,
                                          backgroundColor: Colors.white24,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Expand video',
                                      onPressed: () => _showPreview(controller),
                                      color: Colors.white,
                                      icon: const Icon(Icons.open_in_full),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _FullscreenVideoPreview extends StatefulWidget {
  const _FullscreenVideoPreview({required this.controller});

  final VideoPlayerController controller;

  @override
  State<_FullscreenVideoPreview> createState() =>
      _FullscreenVideoPreviewState();
}

class _FullscreenVideoPreviewState extends State<_FullscreenVideoPreview> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant _FullscreenVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final aspectRatio = controller.value.aspectRatio > 0
        ? controller.value.aspectRatio
        : 16 / 9;

    return Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 18,
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                IconButton(
                  tooltip: controller.value.isPlaying
                      ? 'Pause video'
                      : 'Play video',
                  onPressed: () => controller.value.isPlaying
                      ? controller.pause()
                      : controller.play(),
                  color: Colors.white,
                  icon: Icon(
                    controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  ),
                ),
                Expanded(
                  child: VideoProgressIndicator(
                    controller,
                    allowScrubbing: true,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    colors: const VideoProgressColors(
                      playedColor: Colors.white,
                      bufferedColor: Colors.white38,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: SafeArea(
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Close preview',
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyVideoState extends StatelessWidget {
  const _EmptyVideoState({
    required this.isDragging,
    required this.onChooseVideo,
  });

  final bool isDragging;
  final VoidCallback onChooseVideo;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 180),
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDragging
            ? colorScheme.primaryContainer.withValues(alpha: 0.55)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        border: Border.all(
          color: isDragging ? colorScheme.primary : colorScheme.outlineVariant,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_outlined, size: 38, color: colorScheme.primary),
          const SizedBox(height: 8),
          Text(isDragging ? 'Drop video here' : 'Drag a video here'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onChooseVideo,
            icon: const Icon(Icons.folder_open),
            label: const Text('Choose video'),
          ),
        ],
      ),
    );
  }
}

class _VideoUnavailable extends StatelessWidget {
  const _VideoUnavailable();

  @override
  Widget build(BuildContext context) {
    return const AspectRatio(
      aspectRatio: 16 / 9,
      child: Center(
        child: Text('Video unavailable', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
