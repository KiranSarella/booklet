import 'package:booklet/importing/html_importer.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/code_block_component.dart';

import 'dart:convert';

import 'package:booklet/ui/detail/editor/editor_search.dart';

import 'package:booklet/ui/detail/editor/editor_history.dart';
import 'package:booklet/business/page_content.dart';
import 'package:booklet/business/components_business/component_def.dart';
import 'package:booklet/ui/components/component.dart';
import 'package:booklet/ui/components/inbuilt_components/inbuilt_components.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_snapshot.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter/widgets.dart' show TextSelection;
import 'package:flutter_quill/flutter_quill.dart' show ChangeSource, Document;
import 'package:booklet/ui/sidebar/pages_navigation/pages_navigation_vm.dart';
import 'package:booklet/ui/sidebar/pages_navigation/navigation_node.dart';
import 'package:uuid/uuid.dart';

class EditorVM {
  EditorVM(this.theme, {bool createStarterPage = true}) {
    if (!createStarterPage) {
      return;
    }

    final starterPage = _createPage('Untitled Page', [
      InbuiltComponents.prepareCompoent(const Uuid().v4(), 'title'),
      InbuiltComponents.prepareCompoent(const Uuid().v4(), 'text'),
    ]);
    navigation.addPage(
      pageId: starterPage.id,
      title: starterPage.title,
      referencePageId: null,
    );
    _pagesById[starterPage.id] = starterPage;
    _watchPage(starterPage);
    navigation.selectPage(starterPage.id);
  }

  final PageSettingsController theme;
  final PagesNavigationVM navigation = PagesNavigationVM();
  final Map<String, PageContent> _pagesById = {};
  final Map<ComponentState, VoidCallback> _componentListeners = {};
  VoidCallback? onDocumentChanged;
  VoidCallback? onHistoryChanged;
  final Map<String, EditorHistory> _histories = {};
  bool _replayingHistory = false;
  int _transactionDepth = 0;

  EditorHistory? get _history =>
      selectedPage == null ? null : _histories[selectedPage!.id];
  bool get canUndo =>
      !theme.documentSettingsController.isReadOnly &&
      (_history?.canUndo ?? false);
  bool get canRedo =>
      !theme.documentSettingsController.isReadOnly &&
      (_history?.canRedo ?? false);

  /// Replace from a fresh search snapshot; reverse order preserves text offsets.
  int replaceSearchMatches(
    String query,
    String replacement, {
    bool caseSensitive = false,
    int? matchIndex,
  }) {
    if (theme.documentSettingsController.isReadOnly) return 0;
    final matches = findEditorMatches(
      components,
      query,
      caseSensitive: caseSensitive,
    );
    if (matches.isEmpty) return 0;
    return _transaction(() {
      if (matchIndex != null) {
        matches[matchIndex % matches.length].replace(replacement);
        return 1;
      }
      for (final match in matches.reversed) {
        match.replace(replacement);
      }
      return matches.length;
    });
  }

  void breakHistoryGroup() => _history?.breakGroup();

  T _transaction<T>(T Function() action) {
    breakHistoryGroup();
    _transactionDepth++;
    try {
      return action();
    } finally {
      _transactionDepth--;
      if (_transactionDepth == 0) {
        _recordHistory();
        breakHistoryGroup();
      }
    }
  }

  void _recordHistory({String? mergeKey}) {
    final page = selectedPage;
    if (_replayingHistory || _transactionDepth > 0 || page == null) return;
    final history = _histories.putIfAbsent(
      page.id,
      () => EditorHistory(_captureHistory(page)),
    );
    if (history.record(_captureHistory(page), mergeKey: mergeKey)) {
      onHistoryChanged?.call();
    }
  }

  EditorHistoryState _captureHistory(PageContent page) => EditorHistoryState(
    [
      for (final box in page.components)
        {
          'id': box.component.id,
          'snapshot': ComponentSnapshot.capture(box).toJson(),
        },
    ],
    selectedIds: _selectedComponents.map((box) => box.component.id).toList(),
    carets: {
      for (final box in page.components)
        if (box.component.state is TextComponentState)
          box.component.id: [
            (box.component.state as TextComponentState)
                .controller
                .selection
                .baseOffset,
            (box.component.state as TextComponentState)
                .controller
                .selection
                .extentOffset,
          ],
    },
  );

  void undo() {
    if (canUndo) _restoreHistory(_history!.undo());
  }

  void redo() {
    if (canRedo) _restoreHistory(_history!.redo());
  }

  void _restoreHistory(EditorHistoryState target) {
    final page = selectedPage!;
    _replayingHistory = true;
    try {
      clearSelectedComponent();
      final existing = {
        for (final box in page.components) box.component.id: box,
      };
      final restored = <ComponentBox>[];
      for (final entry in target.components) {
        final id = entry['id'] as String;
        final data = Map<String, dynamic>.from(entry['snapshot'] as Map);
        final old = existing.remove(id);
        if (old != null &&
            jsonEncode(ComponentSnapshot.capture(old).toJson()) ==
                jsonEncode(data)) {
          restored.add(old);
        } else {
          if (old != null) {
            _unwatchComponent(old.component.state);
            old.dispose();
          }
          final box = ComponentSnapshot.fromJson(data).instantiate(id: id);
          restored.add(box);
          _watchComponent(box);
        }
      }
      for (final box in existing.values) {
        _unwatchComponent(box.component.state);
        box.dispose();
      }
      page.components
        ..clear()
        ..addAll(restored);
      for (final box in restored) {
        final caret = target.carets[box.component.id];
        final state = box.component.state;
        if (caret != null && state is TextComponentState) {
          final end = state.controller.document.length - 1;
          state.controller.updateSelection(
            TextSelection(
              baseOffset: caret[0].clamp(0, end),
              extentOffset: caret[1].clamp(0, end),
            ),
            ChangeSource.local,
          );
        }
        if (target.selectedIds.contains(box.component.id)) {
          box.isSelected = true;
          _selectedComponents.add(box);
          _selectedComponent = box;
        }
      }
    } finally {
      _replayingHistory = false;
    }
    onDocumentChanged?.call();
    onHistoryChanged?.call();
  }

  ComponentBox? _selectedComponent;
  final Set<ComponentBox> _selectedComponents = {};
  int? _anchorIndex;
  String? _documentPath;

  PageContent? get selectedPage => navigation.selectedPageId == null
      ? null
      : _pagesById[navigation.selectedPageId];

  List<ComponentBox> get components => selectedPage?.components ?? [];
  Iterable<PageContent> get loadedPages => _pagesById.values;
  ComponentBox? get selectedComponent => _selectedComponent;
  Set<ComponentBox> get selectedComponents => _selectedComponents;
  List<ComponentBox> get _listStyleSelection => _selectedComponents.length > 1
      ? _selectedComponents.toList(growable: false)
      : _selectedComponent == null
      ? const []
      : [_selectedComponent!];
  bool get canTransformSelectedComponent =>
      _transformSelection.isNotEmpty &&
      _transformSelection.every(
        (box) => box.component.def.type == ComponentType.text,
      );
  List<ComponentBox> get _transformSelection => _selectedComponents.length > 1
      ? _selectedComponents.toList(growable: false)
      : _selectedComponent == null
      ? const []
      : [_selectedComponent!];
  bool get selectedHasFocusBar =>
      _listStyleSelection.isNotEmpty &&
      _listStyleSelection.every((box) => box.hasFocusBar);

  void toggleFocusBarOnSelection() {
    _transaction(() {
      if (theme.documentSettingsController.isReadOnly) return;
      final selection = _listStyleSelection;
      if (selection.isEmpty) return;
      final enable = !selectedHasFocusBar;
      for (final box in selection) {
        box.hasFocusBar = enable;
      }
      _documentChanged();
    });
  }

  String? get selectedListKind {
    final kinds = <String>{};
    for (final component in _listStyleSelection) {
      switch (component.component.state) {
        case BulletedListComponentState():
          kinds.add('bullet');
        case NumberedListComponentState():
          kinds.add('numbered');
      }
    }
    return kinds.length == 1 ? kinds.single : null;
  }

  String? get selectedListStyle {
    final kind = selectedListKind;
    if (kind == null) return null;

    final styles = <String>{};
    for (final component in _listStyleSelection) {
      final state = component.component.state;
      if (kind == 'bullet' && state is BulletedListComponentState) {
        styles.add(state.symbol);
      } else if (kind == 'numbered' && state is NumberedListComponentState) {
        styles.add(state.numberStyle);
      }
    }
    return styles.length == 1 ? styles.single : null;
  }

  List<String> get selectedListStyleOptions {
    if (selectedListKind == 'bullet') {
      return BulletedListComponentState.symbols;
    }
    if (selectedListKind == 'numbered') {
      return NumberedListComponentState.numberStyles;
    }
    return const [];
  }

  void setSelectedListStyle(String value) {
    _transaction(() {
      if (theme.documentSettingsController.isReadOnly) return;
      final kind = selectedListKind;
      if (kind == 'bullet' && _selectedComponents.length <= 1) {
        final selectedState = _selectedComponent?.component.state;
        if (selectedState is! BulletedListComponentState) return;
        for (final component in components) {
          final state = component.component.state;
          if (state is BulletedListComponentState &&
              state.nestingLevel == selectedState.nestingLevel) {
            state.symbol = value;
          }
        }
        return;
      }
      if (kind == 'numbered' && _selectedComponents.length <= 1) {
        final selectedState = _selectedComponent?.component.state;
        if (selectedState is! NumberedListComponentState) return;
        for (final component in components) {
          final state = component.component.state;
          if (state is NumberedListComponentState &&
              state.nestingLevel == selectedState.nestingLevel) {
            state.numberStyle = value;
          }
        }
        return;
      }

      for (final component in _listStyleSelection) {
        final state = component.component.state;
        if (kind == 'bullet' && state is BulletedListComponentState) {
          state.symbol = value;
        } else if (kind == 'numbered' && state is NumberedListComponentState) {
          state.numberStyle = value;
        }
      }
    });
  }

  String? get selectedPageId => navigation.selectedPageId;
  String? get documentPath => _documentPath;

  void replaceNavigation(
    List<NavigationNode> groups, {
    String? selectedPageId,
    String? selectedAssetFolderId,
  }) {
    _unwatchAllComponents();
    for (final page in _pagesById.values) {
      page.dispose();
    }
    _pagesById.clear();
    _histories.clear();
    navigation.replaceGroups(
      groups,
      selectedPageId: selectedPageId,
      selectedAssetFolderId: selectedAssetFolderId,
    );
    _selectedComponent = null;
    _selectedComponents.clear();
    _anchorIndex = null;
  }

  void setSelectedPage(PageContent page, {bool preserveLoadedPages = false}) {
    if (!preserveLoadedPages) {
      _unwatchAllComponents();
      for (final loadedPage in _pagesById.values) {
        if (loadedPage.id != page.id) {
          loadedPage.dispose();
        }
      }
      _pagesById.clear();
    }
    _pagesById[page.id] = page;
    _watchPage(page);
    navigation.selectPage(page.id);
    _selectedComponent = null;
    _selectedComponents.clear();
    _anchorIndex = null;
  }

  void setDocumentChangedCallback(VoidCallback callback) {
    onDocumentChanged = callback;
    _unwatchAllComponents();
    for (final page in _pagesById.values) {
      _watchPage(page);
    }
  }

  void setDocumentPath(String? path) {
    _documentPath = path;
  }

  PageContent _createPage(String title, List<Component> components) {
    final id = const Uuid().v4();
    return PageContent(
      id: id,
      title: title,
      components: [
        for (final component in components) ComponentBox(component: component),
      ],
    );
  }

  void selectPage(String pageId) {
    breakHistoryGroup();
    navigation.selectPage(pageId);
    _selectedComponent = null;
    _selectedComponents.clear();
    _anchorIndex = null;
  }

  void selectNode(NavigationNode node) {
    navigation.selectNode(node);
    if (node.isPage || node.isAssetsFolder) {
      clearSelectedComponent();
    }
  }

  void addGroup() {
    navigation.addGroup();
    _documentChanged();
  }

  NavigationNode addAssetsFolderBelow() {
    clearSelectedComponent();
    final folder = navigation.addAssetsFolder(
      folderId: const Uuid().v4(),
      placement: .below,
    );
    _documentChanged();
    return folder;
  }

  NavigationNode addAssetsFolderInside() {
    clearSelectedComponent();
    final folder = navigation.addAssetsFolder(
      folderId: const Uuid().v4(),
      placement: .child,
    );
    _documentChanged();
    return folder;
  }

  void addPageBelowSelected() {
    _addPage(PagePlacement.below);
  }

  void importHtml(HtmlImportResult result) {
    if (theme.documentSettingsController.isReadOnly) return;
    final components = <Component>[];
    for (final block in result.blocks) {
      final component = InbuiltComponents.prepareCompoent(
        const Uuid().v4(),
        block.kind,
      );
      final state = component.state;
      if (state is TextComponentState && block.delta != null) {
        state.controller.document = Document.fromJson(block.delta!);
      }
      if (state is ListItemComponentState) state.nestingLevel = block.depth;
      if (state is NumberedListComponentState) {
        state.sequenceNumber = block.number ?? 1;
      }
      final mediaUri = Uri.tryParse(block.source ?? '');
      final mediaPath = mediaUri?.scheme == 'file'
          ? mediaUri!.toFilePath()
          : block.source;
      if (state is ImageComponentState) state.mediaPath = mediaPath;
      if (state is VideoComponentState) state.mediaPath = mediaPath;
      if (state is AudioComponentState) state.mediaPath = mediaPath;
      if (state is LinkComponentState) state.setValues(url: block.source ?? '');
      if (state is CodeBlockComponentState) {
        state.controller.text = block.source ?? '';
        state.setLanguage(block.language ?? 'plaintext');
      }
      components.add(component);
    }
    final page = _createPage(result.title, components);
    for (var i = 0; i < result.blocks.length; i++) {
      page.components[i].hasFocusBar = result.blocks[i].focusBar;
    }
    clearSelectedComponent();
    navigation.addPage(
      pageId: page.id,
      title: page.title,
      placement: PagePlacement.below,
    );
    _pagesById[page.id] = page;
    _watchPage(page);
    navigation.selectPage(page.id);
    _documentChanged();
  }

  void importMarkdown(String markdown, {required String fileName}) {
    if (theme.documentSettingsController.isReadOnly) return;
    final components = <Component>[];
    final focusBarIndexes = <int>{};
    final blocks = markdown.replaceAll('\r\n', '\n').split(RegExp(r'\n\s*\n+'));
    for (final block in blocks) {
      final value = block.trim();
      if (value.isEmpty) continue;
      final lines = value.split('\n').map((line) => line.trim()).toList();
      final heading = lines.length == 1
          ? RegExp(r'^(#{1,6})\s+(.+?)\s*#*\s*$').firstMatch(lines.single)
          : null;
      if (heading != null) {
        final kind = switch (heading.group(1)!.length) {
          1 => 'title',
          2 => 'heading',
          3 => 'subheading',
          _ => 'text',
        };
        _appendMarkdownComponent(components, kind, heading.group(2)!);
        continue;
      }

      final quoteLines = lines.where((line) => line.startsWith('>')).toList();
      if (quoteLines.length == lines.length) {
        final text = quoteLines
            .map((line) => line.replaceFirst(RegExp(r'^>\s?'), ''))
            .join('\n');
        focusBarIndexes.add(components.length);
        _appendMarkdownComponent(components, 'text', text);
        continue;
      }

      final hasListOrQuote = lines.any(
        (line) => RegExp(r'^(?:[-*+]\s+|\d+[.)]\s+|>\s?)').hasMatch(line),
      );
      if (!hasListOrQuote) {
        _appendMarkdownComponent(components, 'text', lines.join('\n'));
        continue;
      }

      for (final line in lines) {
        final task = RegExp(r'^[-*+]\s+\[([ xX])\]\s+(.*)$').firstMatch(line);
        if (task != null) {
          final component = _appendMarkdownComponent(
            components,
            'checklist',
            task.group(2)!,
          );
          (component.state as ChecklistComponentState).isChecked = task
              .group(1)!
              .trim()
              .isNotEmpty;
          continue;
        }
        final numbered = RegExp(r'^(\d+)[.)]\s+(.*)$').firstMatch(line);
        if (numbered != null) {
          final component = _appendMarkdownComponent(
            components,
            'numbered_list',
            numbered.group(2)!,
          );
          (component.state as NumberedListComponentState).sequenceNumber =
              int.tryParse(numbered.group(1)!) ?? 1;
          continue;
        }
        final bullet = RegExp(r'^[-*+]\s+(.*)$').firstMatch(line);
        if (bullet != null) {
          _appendMarkdownComponent(
            components,
            'bulleted_list',
            bullet.group(1)!,
          );
          continue;
        }
        final quote = RegExp(r'^>\s?(.*)$').firstMatch(line);
        if (quote != null) {
          focusBarIndexes.add(components.length);
          _appendMarkdownComponent(components, 'text', quote.group(1)!);
          continue;
        }
        _appendMarkdownComponent(components, 'text', line);
      }
    }
    final pageTitle = fileName
        .replaceFirst(
          RegExp(r'\.(md|markdown|mdown)$', caseSensitive: false),
          '',
        )
        .trim();
    final page = _createPage(
      pageTitle.isEmpty ? 'Imported Markdown' : pageTitle,
      components,
    );
    for (final index in focusBarIndexes) {
      page.components[index].hasFocusBar = true;
    }
    clearSelectedComponent();
    navigation.addPage(
      pageId: page.id,
      title: page.title,
      placement: PagePlacement.below,
    );
    _pagesById[page.id] = page;
    _watchPage(page);
    _documentChanged();
  }

  Component _appendMarkdownComponent(
    List<Component> components,
    String kind,
    String text,
  ) {
    final component = InbuiltComponents.prepareCompoent(
      const Uuid().v4(),
      kind,
    );
    (component.state as TextComponentState).controller.document.insert(0, text);
    components.add(component);
    return component;
  }

  void addChildPageSelected() {
    _addPage(PagePlacement.child);
  }

  void renameSelectedNode(String title) {
    final selectedNode = navigation.selectedNode;
    if (selectedNode == null) {
      return;
    }
    final nextTitle = title.trim();
    if (selectedNode.title == nextTitle) return;
    final node = navigation.renameNode(selectedNode, nextTitle);
    final pageId = node?.pageId;
    if (pageId != null) {
      _pagesById[pageId]?.title = node!.title;
    }
    _documentChanged();
  }

  NavigationNode? deleteSelectedNode() {
    final selectedNode = navigation.selectedNode;
    if (selectedNode == null) {
      return null;
    }
    final selectedPageId = navigation.selectedPageId;
    final selectedPageWasDeleted = _containsPage(selectedNode, selectedPageId);
    final removedNode = navigation.deleteNode(selectedNode);
    if (removedNode == null) {
      return null;
    }
    _disposePages(removedNode);
    if (selectedPageWasDeleted) {
      clearSelectedComponent();
    }
    _documentChanged();
    return removedNode;
  }

  bool _containsPage(NavigationNode node, String? pageId) {
    if (pageId == null) {
      return false;
    }
    if (node.pageId == pageId) {
      return true;
    }
    return node.children.any((child) => _containsPage(child, pageId));
  }

  void _disposePages(NavigationNode node) {
    final pageId = node.pageId;
    if (pageId != null) {
      _histories.remove(pageId);
      final page = _pagesById.remove(pageId);
      if (page != null) {
        for (final component in page.components) {
          _unwatchComponent(component.component.state);
        }
        page.dispose();
      }
    }
    for (final child in node.children) {
      _disposePages(child);
    }
  }

  void _addPage(PagePlacement placement) {
    clearSelectedComponent();
    final page = _createPage('Untitled page', [
      InbuiltComponents.prepareCompoent(const Uuid().v4(), "heading"),
    ]);
    navigation.addPage(
      pageId: page.id,
      title: page.title,
      placement: placement,
    );
    _pagesById[page.id] = page;
    _watchPage(page);
    _documentChanged();
  }

  // MARK: - Components

  void selectComponent(ComponentBox component) {
    if (_selectedComponent != component) breakHistoryGroup();
    final index = components.indexOf(component);
    if (index == -1) {
      return;
    }
    for (final item in components) {
      if (item != component) {
        item.isSelected = false;
        item.clearFocus();
      }
    }
    component.isSelected = true;
    _selectedComponent = component;
    _selectedComponents
      ..clear()
      ..add(component);
    _anchorIndex = index;
  }

  void selectComponentRange(ComponentBox component) {
    final targetIndex = components.indexOf(component);
    if (targetIndex == -1) {
      return;
    }
    final anchor = _anchorIndex ?? targetIndex;
    final lo = anchor < targetIndex ? anchor : targetIndex;
    final hi = anchor < targetIndex ? targetIndex : anchor;
    final range = components.sublist(lo, hi + 1);
    for (final item in components) {
      final inRange = range.contains(item);
      item.isSelected = inRange;
      if (item != component) {
        item.clearFocus();
      }
    }
    _selectedComponents
      ..clear()
      ..addAll(range);
    _selectedComponent = component;
    _anchorIndex = anchor;
  }

  void extendSelectionWithArrowKey(bool moveDown) {
    final current = _selectedComponent;
    if (current == null) {
      return;
    }
    final currentIndex = components.indexOf(current);
    if (currentIndex == -1) {
      return;
    }
    _anchorIndex ??= currentIndex;
    final nextIndex = moveDown ? currentIndex + 1 : currentIndex - 1;
    if (nextIndex < 0 || nextIndex >= components.length) {
      return;
    }
    selectComponentRange(components[nextIndex]);
  }

  void moveSelectedComponent(bool moveDown) {
    final current = _selectedComponent;
    if (current == null) return;
    final currentIndex = components.indexOf(current);
    final nextIndex = currentIndex + (moveDown ? 1 : -1);
    if (currentIndex < 0 || nextIndex < 0 || nextIndex >= components.length) {
      return;
    }
    selectComponent(components[nextIndex]);
  }

  void clearSelectedComponent() {
    breakHistoryGroup();
    for (final component in components) {
      component.isSelected = false;
      component.clearFocus();
    }
    _selectedComponent = null;
    _selectedComponents.clear();
    _anchorIndex = null;
  }

  ComponentBox createComponentBelow(int index, {TextSelection? selection}) {
    return _transaction(() {
      if (theme.documentSettingsController.isReadOnly) {
        throw StateError('Cannot add components while read-only');
      }
      final page = selectedPage;
      if (page == null) {
        throw StateError('No page is selected');
      }

      TextComponentState? sourceState;
      ListItemComponentState? sourceListState;
      List<Map<String, dynamic>>? prefixDelta;
      List<dynamic>? trailingDelta;
      var componentType = 'text';
      if (selection != null &&
          selection.isValid &&
          index >= 0 &&
          index < page.components.length) {
        final source = page.components[index];
        final state = source.component.state;
        if (source.isTextComponent && state is TextComponentState) {
          if (state is ListItemComponentState &&
              selection.isCollapsed &&
              state.output.trim().isEmpty) {
            if (state.nestingLevel > 0) {
              state.nestingLevel--;
              selectComponent(source);
              _documentChanged();
              return source;
            }
            _replaceComponentWithType(source, 'text', delta: state.textDelta);
            selectComponent(source);
            _documentChanged();
            return source;
          }
          final sourceDocument = state.controller.document;
          final maxOffset = sourceDocument.length - 1;
          final start = selection.start.clamp(0, maxOffset).toInt();
          final end = selection.end.clamp(start, maxOffset).toInt();
          final sourceDelta = sourceDocument.toDelta();
          final prefix = sourceDelta.slice(0, start).toJson();
          final trailing = sourceDelta.slice(end).toJson();
          _ensureDeltaEndsWithNewline(prefix);
          _ensureDeltaEndsWithNewline(trailing);
          sourceState = state;
          prefixDelta = prefix;
          trailingDelta = trailing;
          if (state is ListItemComponentState) {
            sourceListState = state;
            componentType = source.component.def.key;
          }
        }
      }

      final component = ComponentBox(
        component: InbuiltComponents.prepareCompoent(
          const Uuid().v4(),
          componentType,
        ),
        delta: trailingDelta,
      );
      final newState = component.component.state;
      if (sourceListState is BulletedListComponentState &&
          newState is BulletedListComponentState) {
        newState
          ..symbol = sourceListState.symbol
          ..nestingLevel = sourceListState.nestingLevel;
      } else if (sourceListState is NumberedListComponentState &&
          newState is NumberedListComponentState) {
        newState
          ..numberStyle = sourceListState.numberStyle
          ..nestingLevel = sourceListState.nestingLevel;
      } else if (sourceListState != null &&
          newState is ListItemComponentState) {
        newState.nestingLevel = sourceListState.nestingLevel;
      }
      page.components.insert(index + 1, component);
      if (sourceState != null && prefixDelta != null) {
        sourceState.controller.document = Document.fromJson(prefixDelta);
      }
      _watchComponent(component);
      selectComponent(component);
      _documentChanged();
      return component;
    });
  }

  /// Splits [text] on newlines: the first line goes into the component at
  /// [index], each remaining line into a new component below. Returns the last
  /// component, or null when [text] has no newline (default paste applies).
  ComponentBox? pasteTextLines(int index, String text) {
    return _transaction(() {
      final page = selectedPage;
      if (theme.documentSettingsController.isReadOnly ||
          page == null ||
          index < 0 ||
          index >= page.components.length) {
        return null;
      }
      final lines = text
          .split(RegExp(r'\r\n|\r|\n'))
          .where((line) => line.trim().isNotEmpty)
          .toList();
      final source = page.components[index];
      final state = source.component.state;
      if (lines.length < 2 ||
          !source.isTextComponent ||
          state is! TextComponentState) {
        return null;
      }

      final controller = state.controller;
      final selection = controller.selection;
      final start = selection.start.clamp(0, controller.document.length - 1);
      final end = selection.end.clamp(start, controller.document.length - 1);
      controller.replaceText(
        start,
        end - start,
        lines.first,
        TextSelection.collapsed(offset: start + lines.first.length),
      );

      var current = source;
      var currentIndex = index;
      var cursor = start + lines.first.length;
      for (final line in lines.skip(1)) {
        current = createComponentBelow(
          currentIndex,
          selection: TextSelection.collapsed(offset: cursor),
        );
        currentIndex++;
        final newState = current.component.state as TextComponentState;
        newState.controller.replaceText(
          0,
          0,
          line,
          TextSelection.collapsed(offset: line.length),
        );
        cursor = line.length;
      }
      return current;
    });
  }

  void _replaceComponentWithType(
    ComponentBox box,
    String type, {
    required List<dynamic>? delta,
  }) {
    final previousComponent = box.component;
    final previousState = previousComponent.state;
    final replacement = InbuiltComponents.prepareCompoent(
      previousComponent.id,
      type,
    )..initialize(delta: delta);
    replacement.state.isSelected = previousState.isSelected;
    box.component = replacement;
    _unwatchComponent(previousState);
    _watchComponent(box);
    previousComponent.dispose();
  }

  ComponentBox? mergeTextComponentWithPrevious(int index) {
    return _transaction(() {
      if (theme.documentSettingsController.isReadOnly) {
        return null;
      }
      final page = selectedPage;
      if (page == null || index <= 0 || index >= page.components.length) {
        return null;
      }

      final current = page.components[index];
      if (!current.isTextComponent) {
        return null;
      }

      final currentState = current.component.state as TextComponentState;
      final currentDocument = currentState.controller.document;
      final previous = index > 0 ? page.components[index - 1] : null;
      final isEmpty = currentDocument.length == 1;
      if (!isEmpty && (previous == null || !previous.isTextComponent)) {
        return null;
      }

      TextComponentState? previousState;
      if (previous?.isTextComponent == true) {
        previousState = previous!.component.state as TextComponentState;
      }
      final previousEndOffset = previousState == null
          ? null
          : previousState.controller.document.length - 1;
      if (!isEmpty && previousState != null) {
        final mergedDelta = previousState.controller.document.toDelta().concat(
          currentDocument.toDelta(),
          trimNewLine: true,
        );
        previousState.controller.document = Document.fromJson(
          mergedDelta.toJson(),
        );
      }

      page.components.removeAt(index);
      _unwatchComponent(current.component.state);
      current.dispose();
      if (previous != null) {
        selectComponent(previous);
        if (previousState != null && previousEndOffset != null) {
          previousState.controller.updateSelection(
            TextSelection.collapsed(offset: previousEndOffset),
            ChangeSource.local,
          );
        }
      } else {
        _selectedComponent = null;
        _selectedComponents.clear();
        _anchorIndex = null;
      }
      _documentChanged();
      return previous;
    });
  }

  void _ensureDeltaEndsWithNewline(List<Map<String, dynamic>> delta) {
    final lastInsert = delta.isEmpty ? null : delta.last['insert'];
    if (lastInsert is! String || !lastInsert.endsWith('\n')) {
      delta.add({'insert': '\n'});
    }
  }

  ComponentBox createComponentBelowType(int index, String type) {
    return _transaction(() {
      if (theme.documentSettingsController.isReadOnly) {
        throw StateError('Cannot add components while read-only');
      }
      final page = selectedPage;
      if (page == null) {
        throw StateError('No page is selected');
      }
      final component = ComponentBox(
        component: InbuiltComponents.prepareCompoent(const Uuid().v4(), type),
      );
      page.components.insert(index + 1, component);
      _watchComponent(component);
      selectComponent(component);
      _documentChanged();
      return component;
    });
  }

  void transformSelectedComponent(String type) {
    _transaction(() {
      if (theme.documentSettingsController.isReadOnly) {
        return;
      }
      final selection = _transformSelection;
      if (selection.isEmpty || !canTransformSelectedComponent) {
        return;
      }

      for (final selected in selection) {
        final oldComponent = selected.component;
        final newComponent = InbuiltComponents.prepareCompoent(
          oldComponent.id,
          type,
        );
        if (newComponent.def.type != ComponentType.text) {
          newComponent.dispose();
          return;
        }

        newComponent.initialize(delta: oldComponent.textDelta);
        newComponent.state.isSelected = oldComponent.state.isSelected;
        selected.component = newComponent;
        _unwatchComponent(oldComponent.state);
        _watchComponent(selected);
        oldComponent.dispose();
      }
      _documentChanged();
    });
  }

  // MARK: - Copy / paste

  List<ComponentSnapshot> captureSelectedComponents() {
    if (_selectedComponents.isEmpty) {
      final selected = _selectedComponent;
      return selected == null
          ? const []
          : [ComponentSnapshot.capture(selected)];
    }
    return [
      for (final box in components)
        if (_selectedComponents.contains(box)) ComponentSnapshot.capture(box),
    ];
  }

  List<ComponentBox> pasteComponents(List<ComponentSnapshot> snapshots) {
    return _transaction(() {
      if (theme.documentSettingsController.isReadOnly || snapshots.isEmpty) {
        return const [];
      }
      final page = selectedPage;
      if (page == null) {
        return const [];
      }
      final reference = _selectedComponent;
      var insertIndex = reference != null
          ? page.components.indexOf(reference)
          : page.components.length - 1;

      final pasted = <ComponentBox>[];
      for (final snapshot in snapshots) {
        insertIndex++;
        final box = snapshot.instantiate();
        page.components.insert(insertIndex, box);
        _watchComponent(box);
        pasted.add(box);
      }

      selectComponent(pasted.first);
      if (pasted.length > 1) {
        selectComponentRange(pasted.last);
      }
      _documentChanged();
      return pasted;
    });
  }

  void deleteSelectedComponent() {
    _transaction(() {
      if (theme.documentSettingsController.isReadOnly) {
        return;
      }
      final page = selectedPage;
      if (page == null) {
        return;
      }
      final toDelete = _selectedComponents.isNotEmpty
          ? List<ComponentBox>.from(_selectedComponents)
          : (_selectedComponent == null
                ? <ComponentBox>[]
                : [_selectedComponent!]);
      for (final component in toDelete) {
        if (page.components.remove(component)) {
          _unwatchComponent(component.component.state);
          component.isSelected = false;
          component.dispose();
        }
      }
      _selectedComponent = null;
      _selectedComponents.clear();
      _anchorIndex = null;
      _documentChanged();
    });
  }

  void dispose() {
    _unwatchAllComponents();
    for (final page in _pagesById.values) {
      page.dispose();
    }
  }

  void _watchPage(PageContent page) {
    _histories.putIfAbsent(page.id, () => EditorHistory(_captureHistory(page)));
    for (final component in page.components) {
      _watchComponent(component);
    }
  }

  void _watchComponent(ComponentBox component) {
    final state = component.component.state;
    if (_componentListeners.containsKey(state)) return;
    void listener() {
      _recordHistory(
        mergeKey: state is TextComponentState ? component.component.id : null,
      );
      onDocumentChanged?.call();
    }

    _componentListeners[state] = listener;
    state.addListener(listener);
  }

  void _unwatchComponent(ComponentState state) {
    final listener = _componentListeners.remove(state);
    if (listener != null) {
      state.removeListener(listener);
    }
  }

  void _unwatchAllComponents() {
    for (final entry in _componentListeners.entries) {
      entry.key.removeListener(entry.value);
    }
    _componentListeners.clear();
  }

  void _documentChanged() {
    _recordHistory();
    onDocumentChanged?.call();
  }
}
