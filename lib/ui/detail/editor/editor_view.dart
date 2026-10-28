import 'dart:async';

import 'package:flutter/material.dart' hide PageView;
import 'package:flutter/services.dart';
import 'package:booklet/ui/detail/editor/editor_search.dart';

import 'package:booklet/application/editor_controller.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/detail/editor/editor_vm.dart';
import 'package:booklet/ui/detail/editor/editor_minimap.dart';
import 'package:booklet/ui/detail/editor/table_of_contents_button.dart';
import 'package:booklet/ui/detail/editor/options_dock/opitons_dock.dart';
import 'package:booklet/ui/detail/editor/page_settings/page_settings_view.dart';
import 'package:booklet/ui/detail/editor/page_settings/page_settings_vm.dart';
import 'package:booklet/ui/detail/editor/page_view/page_view.dart';

class EditorView extends StatefulWidget {
  const EditorView({super.key, required this.controller});

  final EditorController controller;

  @override
  State<EditorView> createState() => EditorViewState();
}

class EditorViewState extends State<EditorView> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _viewportKey = GlobalKey();
  bool _showMinimap = false;
  bool _showSearch = false;
  bool _showReplace = false;
  bool _searchCaseSensitive = false;
  final _replaceController = TextEditingController();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode(debugLabel: 'editor-search');
  int _searchIndex = 0;
  EditorSearchMatch? _activeSearchMatch;

  void _clearSearchSelection() {
    final match = _activeSearchMatch;
    _activeSearchMatch = null;
    if (match != null && _viewModel.components.contains(match.component)) {
      match.clearSelection();
    }
  }

  List<EditorSearchMatch> get _searchMatches => _showSearch
      ? findEditorMatches(
          _viewModel.components,
          _searchController.text,
          caseSensitive: _searchCaseSensitive,
        )
      : const [];

  void _replaceSearch({bool all = false}) {
    if (widget.controller.documentSettingsController.isReadOnly) return;
    final count = _viewModel.replaceSearchMatches(
      _searchController.text,
      _replaceController.text,
      caseSensitive: _searchCaseSensitive,
      matchIndex: all ? null : _searchIndex,
    );
    if (count == 0) return;
    _navigateSearch(0);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Replaced $count ${count == 1 ? 'match' : 'matches'}'),
      ),
    );
  }

  void _openSearch() {
    setState(() => _showSearch = true);
    _searchFocusNode.requestFocus();
    _searchController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _searchController.text.length,
    );
  }

  void _closeSearch() {
    _clearSearchSelection();
    setState(() {
      _showSearch = false;
      _showReplace = false;
    });
    _pageFocusNode.requestFocus();
  }

  void _navigateSearch(int step, {bool reset = false}) {
    _clearSearchSelection();
    final matches = _searchMatches;
    setState(() {
      _searchIndex = matches.isEmpty || reset
          ? 0
          : (_searchIndex + step) % matches.length;
    });
    if (matches.isEmpty) return;
    final match = matches[_searchIndex];
    // Keep typing in the search field while selecting the result in the page.
    match.select();
    _activeSearchMatch = match;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _viewModel.components.contains(match.component)) {
        _scrollToComponent(match.component);
      }
    });
  }

  final _optionsDockKey = GlobalKey<OptionsDockState>();
  final FocusNode _pageFocusNode = FocusNode(debugLabel: 'page-shortcuts');

  EditorVM get _viewModel => widget.controller.viewModel;

  void selectComponent(ComponentBox component) {
    // Don't steal focus back to the page when this selection is the result
    // of the component's own text field gaining focus (entering edit mode).
    final claimPageFocus = !component.isFocused;
    setState(() => _viewModel.selectComponent(component));
    if (claimPageFocus) {
      _pageFocusNode.requestFocus();
    }
  }

  void selectComponentRange(ComponentBox component) {
    final claimPageFocus = !component.isFocused;
    setState(() => _viewModel.selectComponentRange(component));
    if (claimPageFocus) {
      _pageFocusNode.requestFocus();
    }
  }

  KeyEventResult _handlePageKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isShiftPressed) {
      final selected = _viewModel.selectedComponent;
      if (selected == null || selected.isFocused) {
        return KeyEventResult.ignored;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() => _viewModel.extendSelectionWithArrowKey(true));
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() => _viewModel.extendSelectionWithArrowKey(false));
        return KeyEventResult.handled;
      }
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final selected = _viewModel.selectedComponent;
      if (selected != null && !selected.isFocused) {
        setState(
          () => _viewModel.moveSelectedComponent(
            event.logicalKey == LogicalKeyboardKey.arrowDown,
          ),
        );
        return KeyEventResult.handled;
      }
    }
    final isCommandPressed =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    if (isCommandPressed && event.logicalKey == LogicalKeyboardKey.keyC) {
      final selectedComponent = _viewModel.selectedComponent;
      if (selectedComponent == null || selectedComponent.isFocused) {
        return KeyEventResult.ignored;
      }
      copySelectedComponents();
      return KeyEventResult.handled;
    }
    if (isCommandPressed && event.logicalKey == LogicalKeyboardKey.keyV) {
      if (_viewModel.selectedComponent?.isFocused ?? false) {
        return KeyEventResult.ignored;
      }
      if (!widget.controller.canPasteComponents) {
        return KeyEventResult.ignored;
      }
      pasteComponents();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void copySelectedComponents() {
    unawaited(widget.controller.copySelectedComponents());
  }

  void pasteComponents() {
    unawaited(_pasteComponentsAsync());
  }

  Future<void> _pasteComponentsAsync() async {
    final pasted = await widget.controller.pasteComponents();
    if (!mounted || pasted.isEmpty) {
      return;
    }
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToComponent(pasted.last);
    });
  }

  void clearSelectionAndFocus() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_viewModel.selectedComponent != null) {
      setState(_viewModel.clearSelectedComponent);
    }
  }

  EditorVM get viewModel => _viewModel;

  void dismissOptionsMenu() {
    _optionsDockKey.currentState?.dismissMenu();
  }

  void _createEntryBelow(int index, TextSelection? selection) {
    late final ComponentBox newComponent;
    setState(() {
      newComponent = _viewModel.createComponentBelow(
        index,
        selection: selection,
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToComponent(newComponent);
      newComponent.requestFocus();
    });
  }

  void _moveToTextComponent(int index, bool moveDown) {
    final components = _viewModel.components;
    var targetIndex = index + (moveDown ? 1 : -1);
    while (targetIndex >= 0 && targetIndex < components.length) {
      final target = components[targetIndex];
      if (target.component.state is TextComponentState) {
        setState(() => _viewModel.selectComponent(target));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) target.requestFocus();
        });
        return;
      }
      targetIndex += moveDown ? 1 : -1;
    }
  }

  Future<bool> _pasteTextAt(int index, String text) async {
    ComponentBox? last;
    setState(() {
      last = _viewModel.pasteTextLines(index, text);
    });
    final target = last;
    if (target == null) return false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToComponent(target);
      target.requestFocus();
    });
    return true;
  }

  void _mergeTextComponentWithPrevious(int index) {
    ComponentBox? previousComponent;
    setState(() {
      previousComponent = _viewModel.mergeTextComponentWithPrevious(index);
    });
    if (previousComponent == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToComponent(previousComponent!);
      if (previousComponent!.isTextComponent) {
        previousComponent!.requestFocus();
      }
    });
  }

  void addComponentBelowSelected(String type) {
    final selectedComponent = _viewModel.selectedComponent;
    final selectedIndex = selectedComponent == null
        ? -1
        : _viewModel.components.indexOf(selectedComponent);
    late final ComponentBox newComponent;
    setState(() {
      newComponent = _viewModel.createComponentBelowType(selectedIndex, type);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToComponent(newComponent);
      newComponent.requestFocus();
    });
  }

  /*

May this day of your birth be auspicious!

*/

  void deleteSelectedComponent() {
    setState(_viewModel.deleteSelectedComponent);
  }

  void transformSelectedComponent(String type) {
    setState(() => _viewModel.transformSelectedComponent(type));
  }

  void _scrollToComponent(ComponentBox component) {
    final componentContext = component.componentKey.currentContext;
    if (componentContext == null) {
      return;
    }

    Scrollable.ensureVisible(
      componentContext,
      alignment: 0.5,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addEarlyKeyEventHandler(_handleHistoryKey);
  }

  void _applyHistory({bool redo = false}) {
    redo ? _viewModel.redo() : _viewModel.undo();
    _pageFocusNode.requestFocus();
  }

  KeyEventResult _handleHistoryKey(KeyEvent event) {
    if (event is! KeyDownEvent || !_pageFocusNode.hasFocus) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    if (!keyboard.isMetaPressed && !keyboard.isControlPressed) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyZ) {
      _applyHistory(redo: keyboard.isShiftPressed);
      return KeyEventResult.handled;
    }
    if (keyboard.isControlPressed &&
        event.logicalKey == LogicalKeyboardKey.keyY) {
      _applyHistory(redo: true);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_handleHistoryKey);
    _replaceController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _pageFocusNode.dispose();
    super.dispose();
  }

  void _showPageSettings() {
    showDialog<void>(
      context: context,
      builder: (context) => PageSettingsDialog(
        viewModel: PageSettingsVM(
          pageSettingsController: widget.controller.editorTheme,
          documentSettingsController:
              widget.controller.documentSettingsController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _openSearch,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): _openSearch,
        if (_showSearch)
          const SingleActivator(LogicalKeyboardKey.escape): _closeSearch,
      },
      child: ListenableBuilder(
        listenable: Listenable.merge([
          widget.controller,
          widget.controller.editorTheme,
          widget.controller.documentSettingsController,
          if (_showSearch)
            ..._viewModel.components.map((box) => box.component.state),
        ]),
        builder: (context, _) {
          final matches = _searchMatches;
          return Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: clearSelectionAndFocus,
                child: Focus(
                  focusNode: _pageFocusNode,
                  onKeyEvent: _handlePageKeyEvent,
                  child: ColoredBox(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: SizedBox.expand(
                      child: SingleChildScrollView(
                        key: _viewportKey,
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(
                          _showMinimap ? 210 : 90,
                          90,
                          90,
                          90,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withValues(alpha: 0.1),
                                blurRadius: 30,
                                offset: const Offset(0, -2),
                              ),
                            ],
                          ),
                          child: PageView(
                            searchComponents: matches
                                .map((m) => m.component)
                                .toSet(),
                            activeSearchComponent: matches.isEmpty
                                ? null
                                : matches[_searchIndex % matches.length]
                                      .component,
                            editorTheme: widget.controller.editorTheme,
                            page: widget.controller.selectedPage,
                            onSelectComponent: selectComponent,
                            onSelectComponentRange: selectComponentRange,
                            onCreateEntryBelow: _createEntryBelow,
                            onBackspaceAtStart: _mergeTextComponentWithPrevious,
                            onMoveToAdjacentTextComponent: _moveToTextComponent,
                            onPasteText: _pasteTextAt,
                            onTapEmptySpace: clearSelectionAndFocus,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 82,
                left: 12,
                child: TableOfContentsButton(
                  components: () => _viewModel.components,
                  onSelected: (component) {
                    if (!_viewModel.components.contains(component)) return;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _scrollToComponent(component);
                    });
                  },
                ),
              ),
              Positioned(
                top: 130,
                left: 12,
                child: IconButton(
                  tooltip: _showMinimap ? 'Hide minimap' : 'Show minimap',
                  isSelected: _showMinimap,
                  icon: const Icon(Icons.map_outlined),
                  selectedIcon: const Icon(Icons.map),
                  onPressed: () => setState(() => _showMinimap = !_showMinimap),
                ),
              ),
              if (_showMinimap)
                Positioned(
                  top: 182,
                  bottom: 24,
                  left: 12,
                  width: 172,
                  child: EditorMinimap(
                    components: List.of(_viewModel.components),
                    scrollController: _scrollController,
                    viewportKey: _viewportKey,
                    onNavigate: _scrollToComponent,
                  ),
                ),
              Positioned(
                top: 12,
                right: 86,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Find in page (Ctrl/Cmd+F)',
                      icon: const Icon(Icons.search),
                      onPressed: _openSearch,
                    ),
                    IconButton(
                      tooltip: 'Undo',
                      icon: const Icon(Icons.undo),
                      onPressed: _viewModel.canUndo
                          ? () => _applyHistory()
                          : null,
                    ),
                    IconButton(
                      tooltip: 'Redo',
                      icon: const Icon(Icons.redo),
                      onPressed: _viewModel.canRedo
                          ? () => _applyHistory(redo: true)
                          : null,
                    ),
                  ],
                ),
              ),
              Positioned.fill(
                child: OptionsDock(
                  key: _optionsDockKey,
                  onComponentSelected: addComponentBelowSelected,
                  onComponentTransformed: transformSelectedComponent,
                  onFocusBarToggled: () =>
                      setState(_viewModel.toggleFocusBarOnSelection),
                  onComponentDeleted: deleteSelectedComponent,
                  onComponentsCopied: copySelectedComponents,
                  onComponentsPasted: pasteComponents,
                  onListStyleChanged: (style) =>
                      _viewModel.setSelectedListStyle(style),
                  onPageSettings: _showPageSettings,
                  hasSelection: _viewModel.selectedComponent != null,
                  hasFocusBar: _viewModel.selectedHasFocusBar,
                  canTransformSelection:
                      _viewModel.canTransformSelectedComponent,
                  selectedListKind: _viewModel.selectedListKind,
                  selectedListStyle: _viewModel.selectedListStyle,
                  selectedListStyleOptions: _viewModel.selectedListStyleOptions,
                  canPaste: widget.controller.canPasteComponents,
                  isReadOnly:
                      widget.controller.documentSettingsController.isReadOnly,
                ),
              ),
              if (_showSearch)
                Positioned(
                  top: 62,
                  right: 24,
                  left: 72,
                  child: Align(
                    alignment: Alignment.topRight,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: _showReplace
                                        ? 'Hide replace'
                                        : 'Show replace',
                                    isSelected: _showReplace,
                                    icon: Icon(
                                      _showReplace
                                          ? Icons.expand_more
                                          : Icons.chevron_right,
                                    ),
                                    onPressed: () {
                                      setState(
                                        () => _showReplace = !_showReplace,
                                      );
                                      if (!_showReplace) {
                                        _searchFocusNode.requestFocus();
                                      }
                                    },
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      focusNode: _searchFocusNode,
                                      decoration: const InputDecoration(
                                        hintText: 'Find in page',
                                        border: InputBorder.none,
                                        isDense: true,
                                      ),
                                      onChanged: (_) =>
                                          _navigateSearch(0, reset: true),
                                      onSubmitted: (_) {
                                        _navigateSearch(
                                          HardwareKeyboard
                                                  .instance
                                                  .isShiftPressed
                                              ? -1
                                              : 1,
                                        );
                                        _searchFocusNode.requestFocus();
                                      },
                                    ),
                                  ),
                                  Text(
                                    _searchController.text.isEmpty
                                        ? ''
                                        : matches.isEmpty
                                        ? 'No results'
                                        : '${_searchIndex % matches.length + 1}/${matches.length}',
                                  ),
                                  IconButton(
                                    tooltip: 'Match case',
                                    isSelected: _searchCaseSensitive,
                                    icon: const Icon(Icons.text_fields),
                                    onPressed: () {
                                      setState(
                                        () => _searchCaseSensitive =
                                            !_searchCaseSensitive,
                                      );
                                      _navigateSearch(0, reset: true);
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Previous match (Shift+Enter)',
                                    icon: const Icon(Icons.keyboard_arrow_up),
                                    onPressed: matches.isEmpty
                                        ? null
                                        : () => _navigateSearch(-1),
                                  ),
                                  IconButton(
                                    tooltip: 'Next match (Enter)',
                                    icon: const Icon(Icons.keyboard_arrow_down),
                                    onPressed: matches.isEmpty
                                        ? null
                                        : () => _navigateSearch(1),
                                  ),
                                  IconButton(
                                    tooltip: 'Close search (Esc)',
                                    icon: const Icon(Icons.close),
                                    onPressed: _closeSearch,
                                  ),
                                ],
                              ),
                              if (_showReplace)
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _replaceController,
                                        enabled: !widget
                                            .controller
                                            .documentSettingsController
                                            .isReadOnly,
                                        decoration: const InputDecoration(
                                          hintText: 'Replace with',
                                          border: InputBorder.none,
                                          isDense: true,
                                        ),
                                        onSubmitted: (_) => _replaceSearch(),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed:
                                          matches.isEmpty ||
                                              widget
                                                  .controller
                                                  .documentSettingsController
                                                  .isReadOnly
                                          ? null
                                          : () => _replaceSearch(),
                                      child: const Text('Replace'),
                                    ),
                                    TextButton(
                                      onPressed:
                                          matches.isEmpty ||
                                              widget
                                                  .controller
                                                  .documentSettingsController
                                                  .isReadOnly
                                          ? null
                                          : () => _replaceSearch(all: true),
                                      child: const Text('Replace all'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
