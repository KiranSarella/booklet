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
      readOnly: theme.documentSettingsController.isReadOnly,
    );
  }
}

class LinkComponentView extends StatefulWidget {
  const LinkComponentView({
    super.key,
    required this.state,
    required this.isSelected,
    required this.onSelect,
    this.readOnly = false,
  });

  final LinkComponentState state;
  final bool isSelected;
  final VoidCallback onSelect;
  final bool readOnly;

  @override
  State<LinkComponentView> createState() => _LinkComponentViewState();
}

class _LinkComponentViewState extends State<LinkComponentView> {
  bool _editing = false;

  void _startEditing() {
    widget.state.isFocused = true;
    widget.onSelect();
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _editing) widget.state.urlFocusNode.requestFocus();
    });
  }

  void _finishEditing() {
    widget.state.urlFocusNode.unfocus();
    widget.state.titleFocusNode.unfocus();
    widget.state.isFocused = false;
    setState(() => _editing = false);
  }

  @override
  void didUpdateWidget(covariant LinkComponentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((!widget.isSelected && oldWidget.isSelected) || widget.readOnly) {
      _editing = false;
      widget.state.isFocused = false;
      widget.state.urlFocusNode.unfocus();
      widget.state.titleFocusNode.unfocus();
    }
  }

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

    if (_editing && !widget.readOnly) {
      return Focus(
        onFocusChange: (hasFocus) {
          widget.state.isFocused = hasFocus;
          if (hasFocus) widget.onSelect();
        },
        child: Container(
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

                decoration: const InputDecoration(
                  labelText: 'Link title (optional)',
                  hintText: 'Leave blank to show the full URL',
                ),
                onSubmitted: (_) => _finishEditing(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finishEditing,
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onSelect,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  visibleText.isEmpty ? 'Add a link' : visibleText,
                  style: TextStyle(color: colorScheme.primary),
                ),
              ),
              IconButton(
                tooltip: 'Open in browser',
                icon: const Icon(Icons.open_in_browser),
                onPressed: _openUrl,
              ),
              if (widget.isSelected && !widget.readOnly)
                IconButton(
                  tooltip: 'Edit link',
                  icon: const Icon(Icons.edit),
                  onPressed: _startEditing,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
