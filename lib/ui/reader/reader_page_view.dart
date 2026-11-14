import 'package:flutter/material.dart' hide PageView;
import 'package:booklet/application/editor_controller.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/detail/editor/editor_search.dart';
import 'package:booklet/ui/detail/editor/page_view/page_view.dart';
import 'package:booklet/ui/detail/editor/table_of_contents_button.dart';

/// Shared content renderer with touch controls and no editing command surface.
class ReaderPageView extends StatefulWidget {
  const ReaderPageView({super.key, required this.controller});
  final EditorController controller;

  @override
  State<ReaderPageView> createState() => ReaderPageViewState();
}

class ReaderPageViewState extends State<ReaderPageView> {
  final _query = TextEditingController();
  final _scroll = ScrollController();
  bool _search = false;
  bool _caseSensitive = false;
  int _index = 0;
  EditorSearchMatch? _active;

  List<ComponentBox> get _components => widget.controller.viewModel.components;
  List<EditorSearchMatch> get _matches => findEditorMatches(
    _components,
    _query.text,
    caseSensitive: _caseSensitive,
  );

  void _reveal(ComponentBox component) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = component.componentKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          alignment: 0.3,
          duration: const Duration(milliseconds: 200),
        );
      }
    });
  }

  void _navigate(int step, {bool reset = false}) {
    if (_active != null && _components.contains(_active!.component)) {
      _active!.clearSelection();
    }
    _active = null;
    final matches = _matches;
    setState(
      () => _index = matches.isEmpty || reset
          ? 0
          : (_index + step) % matches.length,
    );
    if (matches.isEmpty) return;
    _active = matches[_index];
    _active!.select();
    _reveal(_active!.component);
  }

  void revealMatch(String query, int index, bool caseSensitive) {
    setState(() {
      _search = true;
      _query.text = query;
      _caseSensitive = caseSensitive;
      _index = index < 0 ? 0 : index;
    });
    _navigate(0);
  }

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches;
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Row(
            children: [
              TableOfContentsButton(
                components: () => _components,
                onSelected: _reveal,
              ),
              TextButton.icon(
                onPressed: () => setState(() => _search = !_search),
                icon: const Icon(Icons.search),
                label: const Text('Find in page'),
              ),
            ],
          ),
        ),
        if (_search)
          Material(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: _query,
                    autofocus: true,
                    decoration: const InputDecoration(hintText: 'Find in page'),
                    onChanged: (_) => _navigate(0, reset: true),
                    onSubmitted: (_) => _navigate(1),
                  ),
                ),
                Row(
                  children: [
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _query.text.isEmpty
                            ? 'Enter search text'
                            : matches.isEmpty
                            ? 'No results'
                            : '${_index % matches.length + 1} / ${matches.length}',
                      ),
                    ),
                    IconButton(
                      tooltip: 'Match case',
                      isSelected: _caseSensitive,
                      icon: const Icon(Icons.text_fields),
                      onPressed: () {
                        setState(() => _caseSensitive = !_caseSensitive);
                        _navigate(0, reset: true);
                      },
                    ),
                    IconButton(
                      tooltip: 'Previous match',
                      icon: const Icon(Icons.keyboard_arrow_up),
                      onPressed: matches.isEmpty ? null : () => _navigate(-1),
                    ),
                    IconButton(
                      tooltip: 'Next match',
                      icon: const Icon(Icons.keyboard_arrow_down),
                      onPressed: matches.isEmpty ? null : () => _navigate(1),
                    ),
                    IconButton(
                      tooltip: 'Close page search',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _active?.clearSelection();
                        _active = null;
                        _query.clear();
                        FocusScope.of(context).unfocus();
                        setState(() => _search = false);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        Expanded(
          child: widget.controller.isLoadingPage
              ? const Center(child: CircularProgressIndicator())
              : widget.controller.selectedPage == null
              ? const Center(child: Text('Choose a page from navigation.'))
              : LayoutBuilder(
                  builder: (context, constraints) => ColoredBox(
                    color: widget.controller.editorTheme.fillsViewport
                        ? widget.controller.editorTheme.pageBackgroundColor
                        : Theme.of(context).scaffoldBackgroundColor,
                    child: SingleChildScrollView(
                      controller: _scroll,
                      padding: EdgeInsets.all(
                        widget.controller.editorTheme.fillsViewport
                            ? 0
                            : MediaQuery.sizeOf(context).width < 600
                            ? 8
                            : 24,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: widget.controller.editorTheme.fillsViewport
                              ? constraints.maxHeight
                              : 0,
                        ),
                        child: PageView(
                          readerLayout: true,
                          editorTheme: widget.controller.editorTheme,
                          page: widget.controller.selectedPage,
                          searchComponents: matches
                              .map((m) => m.component)
                              .toSet(),
                          activeSearchComponent: matches.isEmpty
                              ? null
                              : matches[_index % matches.length].component,
                          onSelectComponent: (_) {},
                          onSelectComponentRange: (_) {},
                          onCreateEntryBelow: (_, _) {},
                          onBackspaceAtStart: (_) {},
                          onPasteText: (_, _) async => false,
                          onTapEmptySpace: () {},
                          onMoveToAdjacentTextComponent: (_, _) {},
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
