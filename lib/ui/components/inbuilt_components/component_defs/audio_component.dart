import 'dart:async';

import 'package:booklet/business/components_business/component_def.dart';
import 'package:booklet/business/components_business/inbuilt_components/inbuit_components_definations.dart';
import 'package:booklet/ui/components/component.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class AudioComponent implements Component {
  AudioComponent({required this.id, String? mediaPath})
    : state = AudioComponentState(mediaPath: mediaPath);

  @override
  final String id;

  @override
  final AudioComponentState state;

  @override
  ComponentDef get def => AudioComponentDef();

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
    required PageSettingsController theme,
    required ComponentState componentState,
    required bool isSelected,
    required VoidCallback onSelect,
    required VoidCallback onCreateBelow,
  }) {
    return AudioComponentView(
      state: state,
      isSelected: isSelected,
      onSelect: onSelect,
    );
  }
}

class AudioComponentView extends StatefulWidget {
  const AudioComponentView({
    super.key,
    required this.state,
    required this.isSelected,
    required this.onSelect,
  });

  final AudioComponentState state;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  State<AudioComponentView> createState() => _AudioComponentViewState();
}

class _AudioComponentViewState extends State<AudioComponentView> {
  static const _audioExtensions = <String>[
    'aac',
    'aiff',
    'flac',
    'm4a',
    'mp3',
    'oga',
    'ogg',
    'opus',
    'wav',
    'wma',
  ];

  final AudioPlayer _player = AudioPlayer();
  String? _loadedPath;
  Object? _loadError;
  int _loadGeneration = 0;
  bool _isDragging = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadedPath = widget.state.mediaPath;
    _loadAudio(_loadedPath);
  }

  @override
  void didUpdateWidget(covariant AudioComponentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.mediaPath != widget.state.mediaPath) {
      _loadedPath = widget.state.mediaPath;
      _loadAudio(_loadedPath);
    }
  }

  Future<void> _loadAudio(String? path) async {
    final generation = ++_loadGeneration;
    _loadError = null;
    if (path == null || path.isEmpty) {
      await _player.stop();
      if (mounted && generation == _loadGeneration) {
        setState(() => _isLoading = false);
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final uri = Uri.tryParse(path);
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        await _player.setUrl(path);
      } else {
        await _player.setFilePath(path);
      }
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() => _isLoading = false);
    } catch (error) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _loadError = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _chooseAudio() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Audio',
          extensions: _audioExtensions,
          mimeTypes: ['audio/*'],
        ),
      ],
    );
    if (file != null) {
      _setAudio(file.path);
    }
  }

  void _setAudio(String path) {
    if (path.isEmpty || !_isAudioPath(path)) {
      return;
    }
    setState(() {
      widget.state.mediaPath = path;
      _loadedPath = path;
    });
    _loadAudio(path);
    widget.onSelect();
  }

  bool _isAudioPath(String path) {
    final extension = path.split('.').last.toLowerCase();
    return _audioExtensions.contains(extension);
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) {
      return '0:00';
    }
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _loadGeneration++;
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.state.mediaPath;
    final colorScheme = Theme.of(context).colorScheme;

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (detail) {
        setState(() => _isDragging = false);
        for (final file in detail.files) {
          if (_isAudioPath(file.path)) {
            _setAudio(file.path);
            break;
          }
        }
      },
      child: GestureDetector(
        onTap: widget.onSelect,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  border: Border.all(
                    color: widget.isSelected || _isDragging
                        ? colorScheme.primary
                        : colorScheme.outlineVariant,
                    width: widget.isSelected || _isDragging ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: path == null || path.isEmpty
                    ? _EmptyAudioState(
                        isDragging: _isDragging,
                        onChooseAudio: _chooseAudio,
                      )
                    : _buildPlayerControls(colorScheme),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerControls(ColorScheme colorScheme) {
    if (_loadError != null) {
      return Row(
        children: [
          Icon(Icons.audio_file, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          const Expanded(child: Text('Audio could not be loaded')),
          IconButton(
            tooltip: 'Choose another audio file',
            onPressed: _chooseAudio,
            icon: const Icon(Icons.folder_open),
          ),
        ],
      );
    }

    return StreamBuilder<PlayerState>(
      stream: _player.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final isPlaying = playerState?.playing ?? false;
        final isCompleted =
            playerState?.processingState == ProcessingState.completed;
        return Row(
          children: [
            IconButton(
              tooltip: isPlaying ? 'Pause audio' : 'Play audio',
              onPressed: _isLoading
                  ? null
                  : () => isPlaying
                        ? _player.pause()
                        : isCompleted
                        ? _player
                              .seek(Duration.zero)
                              .then((_) => _player.play())
                        : _player.play(),
              icon: _isLoading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(isPlaying ? Icons.pause : Icons.play_arrow),
            ),
            Expanded(
              child: StreamBuilder<Duration?>(
                stream: _player.durationStream,
                builder: (context, durationSnapshot) {
                  final duration = durationSnapshot.data ?? Duration.zero;
                  return StreamBuilder<Duration>(
                    stream: _player.positionStream,
                    builder: (context, positionSnapshot) {
                      final position = positionSnapshot.data ?? Duration.zero;
                      final maxMs = duration.inMilliseconds;
                      final currentMs = position.inMilliseconds
                          .clamp(0, maxMs > 0 ? maxMs : 1)
                          .toDouble();
                      return Row(
                        children: [
                          Text(_formatDuration(position)),
                          Expanded(
                            child: Slider(
                              min: 0,
                              max: maxMs > 0 ? maxMs.toDouble() : 1,
                              value: currentMs,
                              onChanged: maxMs <= 0
                                  ? null
                                  : (value) => _player.seek(
                                      Duration(milliseconds: value.round()),
                                    ),
                            ),
                          ),
                          Text(_formatDuration(duration)),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            // IconButton(
            //   tooltip: 'Choose another audio file',
            //   onPressed: _chooseAudio,
            //   icon: const Icon(Icons.folder_open),
            // ),
          ],
        );
      },
    );
  }
}

class _EmptyAudioState extends StatelessWidget {
  const _EmptyAudioState({
    required this.isDragging,
    required this.onChooseAudio,
  });

  final bool isDragging;
  final VoidCallback onChooseAudio;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.audio_file, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            isDragging ? 'Drop an audio file' : 'Add an audio file',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
        IconButton(
          tooltip: 'Choose audio file',
          onPressed: onChooseAudio,
          icon: const Icon(Icons.folder_open),
        ),
      ],
    );
  }
}
