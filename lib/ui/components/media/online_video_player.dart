import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:webview_all/webview_all.dart';

import 'online_video.dart';
import 'video_thumbnail_cache.dart';
import 'youtube_video.dart';

/// Public preview first; web players load only after a user chooses to play.
class OnlineVideoPlayer extends StatefulWidget {
  const OnlineVideoPlayer({super.key, required this.source});
  final String source;

  @override
  State<OnlineVideoPlayer> createState() => _OnlineVideoPlayerState();
}

class _OnlineVideoPlayerState extends State<OnlineVideoPlayer> {
  late final OnlineVideo _video = OnlineVideo.parse(widget.source)!;
  late final Future<Uint8List?> _thumbnail = VideoThumbnailCache.load(
    widget.source,
  );
  WebViewController? _controller;
  bool _loading = false;
  bool _failed = false;
  int _generation = 0;

  Future<void> _play() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
      _controller = null;
    });
    try {
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(Colors.black);
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted && generation == _generation) {
              setState(() => _loading = false);
            }
          },
          onWebResourceError: (error) {
            if (mounted &&
                generation == _generation &&
                error.isForMainFrame == true) {
              setState(() {
                _failed = true;
                _loading = false;
              });
            }
          },
        ),
      );
      await controller.loadRequest(
        _video.embedUri!,
        headers: _video.provider == OnlineVideoProvider.youtube
            ? const {'Referer': '${YoutubeVideo.appOrigin}/'}
            : const {},
      );
      if (mounted && generation == _generation) {
        setState(() {
          _controller = controller;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: _failed
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Preview could not be loaded.',
                        style: TextStyle(color: Colors.white),
                      ),
                      TextButton(onPressed: _play, child: const Text('Retry')),
                    ],
                  ),
                )
              : _controller != null
              ? WebViewWidget(controller: _controller!)
              : FutureBuilder<Uint8List?>(
                  future: _thumbnail,
                  builder: (context, snapshot) => Stack(
                    fit: StackFit.expand,
                    children: [
                      if (snapshot.data != null)
                        Image.memory(
                          snapshot.data!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Center(
                            child: Icon(
                              Icons.video_library_outlined,
                              color: Colors.white54,
                              size: 56,
                            ),
                          ),
                        ),
                      if (snapshot.data == null)
                        const Center(
                          child: Icon(
                            Icons.video_library_outlined,
                            color: Colors.white54,
                            size: 56,
                          ),
                        ),
                      if (_video.embedUri != null)
                        Center(
                          child: _loading
                              ? const CircularProgressIndicator()
                              : IconButton.filled(
                                  tooltip: 'Play ${_video.label} video',
                                  iconSize: 48,
                                  onPressed: _play,
                                  icon: const Icon(Icons.play_arrow),
                                ),
                        ),
                    ],
                  ),
                ),
        ),
        if (_controller != null)
          Positioned(
            top: 4,
            right: 4,
            child: IconButton.filled(
              tooltip: 'Back to thumbnail',
              onPressed: () => setState(() {
                _generation++;
                _controller = null;
                _loading = false;
                _failed = false;
              }),
              icon: const Icon(Icons.stop_circle_outlined),
            ),
          ),
      ],
    );
  }
}
