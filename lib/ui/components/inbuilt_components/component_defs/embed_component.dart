import 'dart:async';

import 'package:html/parser.dart' as html_parser;
import 'package:url_launcher/url_launcher.dart';
import 'package:booklet/ui/components/media/online_video.dart';

import 'package:booklet/business/components_business/component_def.dart';
import 'package:booklet/business/components_business/inbuilt_components/inbuit_components_definations.dart';
import 'package:booklet/ui/components/component.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:webview_all/webview_all.dart';

enum EmbedProvider { youtube, x, instagram, iframe }

class EmbedTarget {
  const EmbedTarget({
    required this.provider,
    required this.html,
    this.thumbnailUrl,
    this.requestUri,
    this.sourceUri,
    this.title,
  });

  final EmbedProvider provider;
  final String html;
  final String? thumbnailUrl;
  final Uri? requestUri;
  final Uri? sourceUri;
  final String? title;
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
        sourceUri: Uri.https('www.youtube.com', '/watch', {
          'v': youtubeVideoId,
        }),
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
      return EmbedTarget(
        provider: EmbedProvider.x,
        html: _xHtml(xPostId),
        sourceUri: Uri.https('x.com', '/i/status/$xPostId'),
      );
    }
    final document = html_parser.parse(content);
    final instagram = document.querySelector('blockquote.instagram-media');
    if (instagram != null) {
      final links = [
        instagram.attributes['data-instgrm-permalink'],
        ...instagram
            .querySelectorAll('a[href]')
            .map((a) => a.attributes['href']),
      ];
      for (final link in links) {
        final online = OnlineVideo.parse(link);
        if (online?.provider == OnlineVideoProvider.instagram) {
          return EmbedTarget(
            provider: EmbedProvider.instagram,
            html: '',
            sourceUri: online!.source,
            requestUri: online.metadataUri,
          );
        }
      }
    }
    final frame = document.querySelector('iframe[src]');
    if (frame != null) {
      var source = frame.attributes['src']!.trim();
      if (source.startsWith('//')) source = 'https:$source';
      final uri = Uri.tryParse(source);
      if (uri == null ||
          !const {'http', 'https'}.contains(uri.scheme) ||
          uri.host.isEmpty) {
        return null;
      }
      // Do not misidentify lookalike provider hosts as their trusted players.
      if (uri.host.contains('youtube.com') && !_isYoutubeHost(uri.host)) {
        return null;
      }
      return EmbedTarget(
        provider: EmbedProvider.iframe,
        html: '',
        requestUri: uri,
        sourceUri: uri,
        title: frame.attributes['title'],
      );
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
    required PageSettingsController theme,
    required ComponentState componentState,
    required bool isSelected,
    required VoidCallback onSelect,
    required VoidCallback onCreateBelow,
  }) {
    return EmbedComponentView(
      state: state,
      isSelected: isSelected,
      onSelect: onSelect,
      isReadOnly: theme.documentSettingsController.isReadOnly,
    );
  }
}

class EmbedComponentView extends StatefulWidget {
  const EmbedComponentView({
    super.key,
    required this.state,
    required this.isSelected,
    required this.onSelect,
    this.isReadOnly = false,
  });

  final EmbedComponentState state;
  final bool isSelected;
  final VoidCallback onSelect;
  final bool isReadOnly;

  @override
  State<EmbedComponentView> createState() => _EmbedComponentViewState();
}

class _EmbedComponentViewState extends State<EmbedComponentView> {
  WebViewController? _webViewController;
  String? _loadError;
  int _loadGeneration = 0;
  bool _isPlaying = false;
  late bool _editing = widget.state.content.trim().isEmpty;

  void _edit() {
    _stopPlayback();
    setState(() => _editing = true);
    widget.onSelect();
  }

  void _apply() {
    if (EmbedContentParser.parse(widget.state.content) == null) {
      setState(
        () => _loadError = 'Paste an iframe or an Instagram/X post embed.',
      );
      return;
    }
    widget.state.focusNode.unfocus();
    setState(() {
      _editing = false;
      _loadError = null;
    });
    _startPlayback();
  }

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
      _loadGeneration++;
      _webViewController = null;
      _isPlaying = false;
      _loadError = null;
      _editing = widget.state.content.trim().isEmpty;
    }
  }

  void _onContentChanged() {
    widget.state.content = widget.state.contentController.text;
    if (mounted) {
      _loadGeneration++;
      setState(() {
        _webViewController = null;
        _isPlaying = false;
        _loadError = null;
      });
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
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            if (mounted &&
                generation == _loadGeneration &&
                error.isForMainFrame == true) {
              setState(
                () => _loadError = 'This embed could not be loaded. Try opening it in your browser.',
              );
            }
          },
        ),
      );
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
    _loadGeneration++;
    setState(() {
      _isPlaying = false;
      _webViewController = null;
      _loadError = null;
    });
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
                    : providerName == 'X / Twitter' ||
                          providerName == 'Instagram'
                    ? Icons.alternate_email
                    : Icons.widgets_outlined,
                size: 42,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                providerName == 'YouTube'
                    ? 'Video preview unavailable'
                    : providerName == 'X / Twitter'
                    ? 'View post from X / Twitter'
                    : 'Load $providerName content',
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
      EmbedProvider.instagram => 'Instagram',
      EmbedProvider.iframe =>
        target?.title?.trim().isNotEmpty == true
            ? target!.title!
            : target!.requestUri!.host,
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
            if (_editing && !widget.isReadOnly)
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
                    hintText: 'Paste iframe code for a map, form, video, or widget; or Instagram/X embed code',
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
                    if (!widget.isReadOnly)
                      IconButton(
                        tooltip: 'Edit embed code',
                        onPressed: _edit,
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    if (target.sourceUri != null)
                      IconButton(
                        tooltip: 'Open in browser',
                        onPressed: () => launchUrl(
                          target.sourceUri!,
                          mode: LaunchMode.externalApplication,
                        ),
                        icon: const Icon(Icons.open_in_browser),
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
            if (_editing && !widget.isReadOnly)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Use Share → Embed on the provider’s site. Supports iframe widgets and Instagram/X posts.',
                    ),
                    if (_loadError != null)
                      Text(
                        _loadError!,
                        style: TextStyle(color: colorScheme.error),
                      ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _apply,
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Show embed'),
                    ),
                  ],
                ),
              )
            else if (!hasValidEmbed)
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Paste supported embed code to display content.',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                    if (!widget.isReadOnly)
                      TextButton.icon(
                        onPressed: _edit,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit embed code'),
                      ),
                  ],
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
                      onPressed: _startPlayback,
                      child: const Text('Retry'),
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
