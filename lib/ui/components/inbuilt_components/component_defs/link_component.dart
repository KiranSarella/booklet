import 'package:booklet/business/components_business/component_def.dart';
import 'package:booklet/business/components_business/inbuilt_components/inbuit_components_definations.dart';
import 'package:booklet/ui/components/component.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LinkComponent implements Component {
  LinkComponent({required this.id, String? url, String? title})
    : state = LinkComponentState(url: url, title: title);

  @override
  final String id;

  @override
  final LinkComponentState state;

  @override
  ComponentDef get def => LinkComponentDef();

  @override
  Object get output => {'url': state.url, 'title': state.title};

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
    return LinkComponentView(
      state: state,
      isSelected: isSelected,
      onSelect: onSelect,
    );
  }
}

class LinkComponentView extends StatefulWidget {
  const LinkComponentView({
    super.key,
    required this.state,
    required this.isSelected,
    required this.onSelect,
  });

  final LinkComponentState state;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  State<LinkComponentView> createState() => _LinkComponentViewState();
}

class _LinkComponentViewState extends State<LinkComponentView> {
  Future<void> _openUrl() async {
    final uri = LinkComponentState.parseWebUri(widget.state.url);
    if (uri == null) {
      _showLaunchError('Enter a valid http or https URL.');
      return;
    }

    try {
      final didLaunch = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!didLaunch && mounted) {
        _showLaunchError('Could not open this link.');
      }
    } catch (_) {
      if (mounted) {
        _showLaunchError('Could not open this link.');
      }
    }
  }

  void _showLaunchError(String message) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final visibleText = widget.state.title.trim().isEmpty
        ? widget.state.url
        : widget.state.title;

    if (widget.isSelected) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          border: Border.all(color: colorScheme.primary, width: 1.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: widget.state.urlController,
              focusNode: widget.state.urlFocusNode,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              onChanged: widget.state.updateUrl,
              onTap: widget.onSelect,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://example.com',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: widget.state.titleController,
              focusNode: widget.state.titleFocusNode,
              textInputAction: TextInputAction.done,
              onChanged: widget.state.updateTitle,
              onTap: widget.onSelect,
              decoration: const InputDecoration(
                labelText: 'Link title (optional)',
                hintText: 'Leave blank to show the full URL',
              ),
            ),
          ],
        ),
      );
    }

    if (visibleText.isEmpty) {
      return Text(
        'Select to add a link',
        style: TextStyle(color: colorScheme.onSurfaceVariant),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onSelect,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: InkWell(
                onTap: _openUrl,
                child: Text(
                  visibleText,
                  style: TextStyle(
                    color: colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
