import 'package:flutter/material.dart';
import 'package:booklet/application/app.dart';
import 'package:booklet/application/appearance_mode.dart';
import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/ui/reader/reader_page_view.dart';
import 'package:booklet/ui/sidebar/booklet_search_view.dart';
import 'package:booklet/ui/sidebar/document_settings/document_information_section.dart';
import 'package:booklet/ui/sidebar/pages_navigation/navigation_node.dart';

class ReaderShell extends StatefulWidget {
  const ReaderShell({
    super.key,
    required this.application,
    required this.onOpen,
  });
  final App application;
  final Future<void> Function() onOpen;

  @override
  State<ReaderShell> createState() => _ReaderShellState();
}

class _ReaderShellState extends State<ReaderShell> {
  GlobalKey<ReaderPageViewState> _pageKey = GlobalKey();
  String? _pageIdentity;
  bool _busy = false;
  final _collapsed = <NavigationNode>{};
  final _scaffold = GlobalKey<ScaffoldState>();
  int _request = 0;
  String? _pageError;
  bool _pinNavigation = false;

  Future<void> _open() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onOpen();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open booklet. Choose a valid .booklet file.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _selectPage(String id) async {
    final request = ++_request;
    setState(() => _pageError = null);
    try {
      await widget.application.editorController.selectPage(
        id,
        saveCurrentPage: false,
      );
      return mounted && request == _request;
    } catch (_) {
      if (mounted && request == _request) {
        setState(
          () => _pageError = 'Could not load this page. Choose another page or reopen the booklet.',
        );
      }
      return false;
    }
  }

  void _search() {
    final controller = widget.application.editorController;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (searchContext) => Scaffold(
          appBar: AppBar(title: const Text('Search booklet')),
          body: SafeArea(
            child: BookletSearchView(
              controller: controller,
              onClose: () => Navigator.of(searchContext).pop(),
              onResult: (pageId, query, index, caseSensitive) async {
                Navigator.of(searchContext).pop();
                if (!await _selectPage(pageId)) return;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _pageKey.currentState?.revealMatch(
                      query,
                      index,
                      caseSensitive,
                    );
                  }
                });
              },
            ),
          ),
        ),
      ),
    );
  }

  void _sheet(Widget child) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: child,
      ),
    );
  }

  void _appearance() {
    final settings = widget.application.documentSettingsController;
    final page = widget.application.editorTheme;
    _sheet(
      ListenableBuilder(
        listenable: Listenable.merge([settings, page]),
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Reading appearance',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            const Text('Document appearance'),
            Wrap(
              spacing: 8,
              children: [
                for (final mode in DocumentAppearanceMode.values)
                  ChoiceChip(
                    label: Text(mode.name),
                    selected: settings.appearanceMode == mode,
                    onSelected: (_) => settings.updateAppearanceMode(mode),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Page appearance'),
            Wrap(
              spacing: 8,
              children: [
                for (final mode in EditorAppearanceMode.values)
                  ChoiceChip(
                    label: Text(mode.name),
                    selected: page.appearanceMode == mode,
                    onSelected: (_) => page.updateAppearanceMode(mode),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Page theme'),
            Wrap(
              spacing: 8,
              children: [
                for (final theme in page.themes)
                  ActionChip(
                    label: Text(theme.name),
                    avatar: CircleAvatar(
                      backgroundColor: theme.pageBackgroundColor,
                      child: Icon(
                        Icons.palette_outlined,
                        size: 16,
                        color: theme.textColor,
                      ),
                    ),
                    onPressed: () => page.applyTheme(theme),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Font size: ${page.baseFontSize.round()}'),
            Wrap(
              spacing: 12,
              children: [
                IconButton(
                  tooltip: 'Decrease font size',
                  onPressed: page.decreaseFontSize,
                  icon: const Icon(Icons.text_decrease),
                ),
                TextButton(
                  onPressed: page.resetFontSize,
                  child: const Text('Reset'),
                ),
                IconButton(
                  tooltip: 'Increase font size',
                  onPressed: page.increaseFontSize,
                  icon: const Icon(Icons.text_increase),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _navigation({required bool drawer}) {
    final controller = widget.application.editorController;
    Widget nodeTile(NavigationNode node, int depth) {
      final expanded = !_collapsed.contains(node);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.only(left: depth * 16.0),
            child: Row(
              children: [
                if (node.children.isNotEmpty)
                  IconButton(
                    tooltip: expanded ? 'Collapse' : 'Expand',
                    icon: Icon(
                      expanded ? Icons.expand_more : Icons.chevron_right,
                    ),
                    onPressed: () => setState(() {
                      if (expanded) {
                        _collapsed.add(node);
                      } else {
                        _collapsed.remove(node);
                      }
                    }),
                  ),
                Expanded(
                  child: ListTile(
                    leading: Icon(node.icon),
                    title: Text(node.title),
                    selected:
                        node.isPage &&
                        controller.viewModel.selectedPageId == node.pageId,
                    onTap: () {
                      if (node.isPage) {
                        if (drawer) Navigator.of(context).pop();
                        _selectPage(node.pageId!);
                      } else {
                        setState(() {
                          if (expanded) {
                            _collapsed.add(node);
                          } else {
                            _collapsed.remove(node);
                          }
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          if (expanded)
            for (final child in node.children) nodeTile(child, depth + 1),
        ],
      );
    }

    return Material(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              title: const Text('Pages'),
              trailing: drawer
                  ? null
                  : IconButton(
                      tooltip: 'Unpin navigation',
                      icon: const Icon(Icons.push_pin),
                      onPressed: () => setState(() => _pinNavigation = false),
                    ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                children: [
                  for (final node in controller.viewModel.navigation.groups)
                    nodeTile(node, 0),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.application.editorController;
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.application,
        controller,
        widget.application.editorTheme,
      ]),
      builder: (context, _) {
        final opened = widget.application.screen == AppScreen.editor;
        final identity =
            '${controller.documentPath}/${controller.viewModel.selectedPageId}';
        if (_pageIdentity != identity) {
          _pageIdentity = identity;
          _pageKey = GlobalKey();
        }
        final wide = MediaQuery.sizeOf(context).width >= 1000;
        final pinned = opened && wide && _pinNavigation;
        return Scaffold(
          key: _scaffold,
          appBar: AppBar(
            title: Text(
              opened
                  ? controller.viewModel.navigation.selectedNode?.title ??
                        'Booklet'
                  : 'Booklet Reader',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            leading: opened
                ? IconButton(
                    tooltip: 'Pages',
                    icon: const Icon(Icons.menu),
                    onPressed: () {
                      if (wide) {
                        setState(() => _pinNavigation = !_pinNavigation);
                      } else {
                        _scaffold.currentState?.openDrawer();
                      }
                    },
                  )
                : null,
            actions: [
              if (opened) ...[
                IconButton(
                  tooltip: 'Search booklet',
                  onPressed: _search,
                  icon: const Icon(Icons.manage_search),
                ),
                IconButton(
                  tooltip: 'Reading appearance',
                  onPressed: _appearance,
                  icon: const Icon(Icons.text_format),
                ),
              ],
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'open') _open();
                  if (value == 'info') {
                    _sheet(
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: DocumentInformationSection(
                          controller: controller,
                        ),
                      ),
                    );
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'open',
                    child: Text('Open booklet'),
                  ),
                  if (opened)
                    const PopupMenuItem(
                      value: 'info',
                      child: Text('Document info'),
                    ),
                ],
              ),
            ],
          ),
          drawer: opened && !wide
              ? Drawer(child: _navigation(drawer: true))
              : null,
          body: SafeArea(
            child: Stack(
              children: [
                if (!opened)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_stories_outlined, size: 64),
                          const SizedBox(height: 24),
                          Text(
                            'Your booklets, ready to read',
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Open a .booklet file.\nDocuments open in read-only mode.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: _busy ? null : _open,
                            icon: const Icon(Icons.folder_open),
                            label: const Text('Open booklet'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      if (pinned)
                        SizedBox(width: 300, child: _navigation(drawer: false)),
                      Expanded(
                        child: _pageError != null
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(_pageError!),
                                ),
                              )
                            : ReaderPageView(
                                key: _pageKey,
                                controller: controller,
                              ),
                      ),
                    ],
                  ),
                if (_busy)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x55000000),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
