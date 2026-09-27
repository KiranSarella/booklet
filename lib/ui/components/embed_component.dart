import 'dart:async';

import 'package:booklet/business/components_business/component_def.dart';
import 'package:booklet/business/components_business/inbuilt_components/inbuit_components_definations.dart';
import 'package:booklet/ui/components/component.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/editor_themes/editor_themes.dart';
import 'package:flutter/material.dart';
import 'package:webview_all/webview_all.dart';

enum EmbedProvider { youtube, x }

class EmbedTarget {
  const EmbedTarget({
    required this.provider,
    required this.html,
    this.thumbnailUrl,
    this.requestUri,
  });

  final EmbedProvider provider;
  final String html;
  final String? thumbnailUrl;
  final Uri? requestUri;
}

class EmbedContentParser {
  static EmbedTarget? parse(String content) {
    final youtubeVideoId =
        RegExp(r'<iframe\b', caseSensitive: false).hasMatch(content)
        ? _youtubeVideoId(content)
        : null;
    if (youtubeVideoId != null) {
      return EmbedTarget(
        provider: EmbedProvider.youtube,
        html: _youtubeHtml(youtubeVideoId),
        thumbnailUrl:
            'https://img.youtube.com/vi/$youtubeVideoId/hqdefault.jpg',
        requestUri: Uri.https(
          'www.youtube-nocookie.com',
          '/embed/$youtubeVideoId',
          {
            'playsinline': '1',
            'enablejsapi': '1',
            'origin': 'https://www.youtube-nocookie.com',
          },
        ),
      );
    }

    final isXEmbedMarkup =
        content.contains('twitter-tweet') ||
        content.contains('platform.twitter.com/widgets.js');
    final xPostId = isXEmbedMarkup ? _xPostId(content) : null;
    if (xPostId != null) {
      return EmbedTarget(provider: EmbedProvider.x, html: _xHtml(xPostId));
    }
    return null;
  }

  static String? _youtubeVideoId(String content) {
    final sources = RegExp(
      r'''\bsrc\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    ).allMatches(content);
    for (final match in sources) {
      var rawSource = match.group(1)!;
      if (rawSource.startsWith('//')) {
        rawSource = 'https:$rawSource';
      }
      final uri = Uri.tryParse(rawSource);
      if (uri == null || uri.scheme != 'https' || !_isYoutubeHost(uri.host)) {
        continue;
      }
      final segments = uri.pathSegments;
      if (segments.length < 2 || segments.first != 'embed') {
        continue;
      }
      final videoId = segments[1];
      if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(videoId)) {
        return videoId;
      }
    }
    return null;
  }

  static String? _xPostId(String content) {
    final matches = RegExp(
      r'''(?:x\.com|twitter\.com)/(?:[^\s"'<>]+?/)?status(?:es)?/(\d+)''',
      caseSensitive: false,
    ).allMatches(content);
    return matches.isEmpty ? null : matches.first.group(1);
  }

  static bool _isYoutubeHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'youtube.com' ||
        normalized == 'www.youtube.com' ||
        normalized == 'youtube-nocookie.com' ||
        normalized == 'www.youtube-nocookie.com';
  }

  static String _youtubeHtml(String videoId) =>
      '''
<!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">
<style>html,body{margin:0;width:100%;height:100%;background:#000;overflow:hidden}iframe{width:100%;height:100%;border:0}</style>
</head><body><iframe src="https://www.youtube-nocookie.com/embed/$videoId?playsinline=1" title="YouTube video" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe></body></html>
''';

  static String _xHtml(String postId) =>
      '''
<!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">
<style>html,body{margin:0;min-height:100%;font-family:system-ui,sans-serif}body{display:flex;justify-content:center}</style>
</head><body><blockquote class="twitter-tweet"><a href="https://x.com/i/status/$postId">View post</a></blockquote>
<script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script></body></html>
''';
}

class EmbedComponent implements Component {
  EmbedComponent({required this.id, String? content})
    : state = EmbedComponentState(content: content);

  @override
  final String id;

  @override
  final EmbedComponentState state;

  @override
  ComponentDef get def => EmbedComponentDef();

  @override
  Object get output => state.output;

  @override
  List<dynamic>? get textDelta => null;

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
    return EmbedComponentView(
      state: state,
      isSelected: isSelected,
      onSelect: onSelect,
    );
  }
}

class EmbedComponentView extends StatefulWidget {
  const EmbedComponentView({
    super.key,
    required this.state,
    required this.isSelected,
    required this.onSelect,
  });

  final EmbedComponentState state;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  State<EmbedComponentView> createState() => _EmbedComponentViewState();
}

class _EmbedComponentViewState extends State<EmbedComponentView> {
  WebViewController? _webViewController;
  String? _loadError;
  int _loadGeneration = 0;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    widget.state.contentController.addListener(_onContentChanged);
  }

  @override
  void didUpdateWidget(covariant EmbedComponentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.contentController != widget.state.contentController) {
      oldWidget.state.contentController.removeListener(_onContentChanged);
      widget.state.contentController.addListener(_onContentChanged);
    }
  }

  void _onContentChanged() {
    widget.state.content = widget.state.contentController.text;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadEmbed(String content) async {
    final generation = ++_loadGeneration;
    final target = EmbedContentParser.parse(content);
    if (target == null) {
      if (mounted) {
        setState(() {
          _webViewController = null;
          _loadError = null;
        });
      }
      return;
    }

    setState(() {
      _webViewController = null;
      _loadError = null;
    });
    try {
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(Colors.transparent);
      final requestUri = target.requestUri;
      if (requestUri != null) {
        await controller.loadRequest(requestUri);
      } else {
        await controller.loadHtmlString(
          target.html,
          baseUrl: 'https://platform.twitter.com/',
        );
      }
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() => _webViewController = controller);
    } catch (_) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() => _loadError = 'This embed could not be loaded.');
    }
  }

  void _startPlayback() {
    setState(() => _isPlaying = true);
    unawaited(_loadEmbed(widget.state.content));
  }

  void _stopPlayback() {
    setState(() => _isPlaying = false);
  }

  Widget _buildProviderPreview(
    EmbedTarget target,
    String providerName,
    ColorScheme colorScheme,
  ) {
    if (target.provider == EmbedProvider.youtube) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              target.thumbnailUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _buildPreviewFallback(providerName, colorScheme),
            ),
            Center(
              child: IconButton.filled(
                tooltip: 'Play YouTube video',
                onPressed: _startPlayback,
                iconSize: 36,
                icon: const Icon(Icons.play_arrow),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: _buildPreviewFallback(
        providerName,
        colorScheme,
        onTap: _startPlayback,
      ),
    );
  }

  Widget _buildPreviewFallback(
    String providerName,
    ColorScheme colorScheme, {
    VoidCallback? onTap,
  }) {
    return Material(
      color: colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                providerName == 'YouTube'
                    ? Icons.play_circle_outline
                    : Icons.alternate_email,
                size: 42,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                providerName == 'YouTube'
                    ? 'Video preview unavailable'
                    : 'View post from X / Twitter',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              if (onTap != null) ...[
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: onTap,
                  child: const Text('Load embed'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _loadGeneration++;
    widget.state.contentController.removeListener(_onContentChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final target = EmbedContentParser.parse(widget.state.content);
    final hasValidEmbed = target != null;
    final providerName = switch (target?.provider) {
      EmbedProvider.youtube => 'YouTube',
      EmbedProvider.x => 'X / Twitter',
      null => 'Embed',
    };

    return Focus(
      onFocusChange: (hasFocus) {
        widget.state.isFocused = hasFocus;
        if (hasFocus) {
          widget.onSelect();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          border: Border.all(
            color: widget.isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant,
            width: widget.isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.isSelected)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: TextField(
                  controller: widget.state.contentController,
                  focusNode: widget.state.focusNode,
                  minLines: 3,
                  maxLines: 8,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  onTap: widget.onSelect,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: const InputDecoration(
                    isCollapsed: false,
                    hintText: 'Paste YouTube iframe or X/Twitter embed code',
                    border: OutlineInputBorder(),
                  ),
                ),
              )
            else if (hasValidEmbed)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: Row(
                  children: [
                    Icon(Icons.code, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(child: Text(providerName)),
                    IconButton(
                      tooltip: 'Edit embed code',
                      onPressed: widget.onSelect,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    if (_isPlaying)
                      IconButton(
                        tooltip: 'Show preview',
                        onPressed: _stopPlayback,
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
              ),
            if (widget.isSelected)
              const SizedBox.shrink()
            else if (!hasValidEmbed)
              Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  'Paste supported embed code to display content.',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              )
            else if (_loadError != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      _loadError!,
                      style: TextStyle(color: colorScheme.error),
                    ),
                    TextButton(
                      onPressed: _stopPlayback,
                      child: const Text('Back to preview'),
                    ),
                  ],
                ),
              )
            else if (_isPlaying && _webViewController == null)
              const SizedBox(
                height: 260,
                child: ColoredBox(
                  color: Color(0xFF161616),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_isPlaying && _webViewController != null)
              SizedBox(
                height: target.provider == EmbedProvider.youtube ? 300 : 480,
                child: WebViewWidget(controller: _webViewController!),
              )
            else
              _buildProviderPreview(target, providerName, colorScheme),
          ],
        ),
      ),
    );
  }
}
