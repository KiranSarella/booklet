import 'package:booklet/application/editor_controller.dart';

import 'booklet_search_view.dart';

import 'package:flutter/material.dart';
import 'package:booklet/ui/sidebar/document_settings/document_settings_view.dart';
import 'package:booklet/ui/sidebar/document_settings/document_settings_vm.dart';

enum SidebarSection {
  pages('Pages', Icons.description_outlined),
  settings('Settings', Icons.settings_outlined);

  const SidebarSection(this.label, this.icon);
  final String label;
  final IconData icon;
}

class BaseSidebarView extends StatefulWidget {
  const BaseSidebarView({
    super.key,
    required this.width,
    required this.controller,
    required this.onSearchResult,
    required this.pagesNavigation,
    required this.documentSettingsViewModel,
  });

  final EditorController controller;
  final void Function(String, String, int, bool) onSearchResult;
  final double width;
  final Widget Function(Widget? searchPanel, VoidCallback onSearch)
  pagesNavigation;
  final DocumentSettingsVM documentSettingsViewModel;

  @override
  State<BaseSidebarView> createState() => BaseSidebarViewState();
}

class BaseSidebarViewState extends State<BaseSidebarView> {
  bool _searching = false;
  final _searchKey = GlobalKey<BookletSearchViewState>();
  void openSearch() {
    setState(() {
      _section = SidebarSection.pages;
      _searching = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchKey.currentState?.focusSearch();
    });
  }

  SidebarSection _section = SidebarSection.pages;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Wrap(
              spacing: 4,
              children: [
                for (final section in SidebarSection.values) ...[
                  _SectionButton(
                    label: section.label,
                    icon: section.icon,
                    selected: section == _section,
                    onPressed: () => setState(() => _section = section),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: switch (_section) {
              SidebarSection.pages => widget.pagesNavigation(
                _searching
                    ? BookletSearchView(
                        key: _searchKey,
                        controller: widget.controller,
                        onResult: widget.onSearchResult,
                        onClose: () => setState(() => _searching = false),
                      )
                    : null,
                openSearch,
              ),
              SidebarSection.settings => DocumentSettingsView(
                viewModel: widget.documentSettingsViewModel,
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _SectionButton extends StatelessWidget {
  const _SectionButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: selected ? scheme.primary : scheme.onSurfaceVariant,
        backgroundColor: selected ? scheme.primaryContainer : null,
      ),
    );
  }
}
