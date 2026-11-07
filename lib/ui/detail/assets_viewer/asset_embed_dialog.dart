import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_all/webview_all.dart';
import 'package:booklet/business/booklet_asset.dart';
import 'package:booklet/ui/components/media/asset_embed.dart';

class AssetEmbedDialog extends StatefulWidget {
  const AssetEmbedDialog({super.key, required this.asset});
  final BookletAsset asset;
  @override
  State<AssetEmbedDialog> createState() => _AssetEmbedDialogState();
}

class _AssetEmbedDialogState extends State<AssetEmbedDialog> {
  WebViewController? _controller;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _failed = false;
      _controller = null;
    });
    try {
      final target = AssetEmbed.parse(widget.asset.embedCode!)!;
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      if (target.html != null) {
        await controller.loadHtmlString(
          target.html!,
          baseUrl: 'https://platform.twitter.com/',
        );
      } else {
        await controller.loadRequest(target.displayUri);
      }
      if (mounted) setState(() => _controller = controller);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    child: SafeArea(
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  widget.asset.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(widget.asset.path),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_browser),
                label: const Text('Open in browser'),
              ),
              IconButton(
                tooltip: 'Close embed',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Expanded(
            child: _failed
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('This provider could not load its embed.'),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _controller == null
                ? const Center(child: CircularProgressIndicator())
                : WebViewWidget(controller: _controller!),
          ),
        ],
      ),
    ),
  );
}
