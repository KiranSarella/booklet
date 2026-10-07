import 'package:booklet/business/page_content.dart';
import 'package:booklet/business/components_business/component_def.dart';
import 'package:booklet/ui/components/component.dart';
import 'package:booklet/ui/components/inbuilt_components.dart';
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

    final starterPage = _createPage('Introduction', [
      InbuiltComponents.prepareCompoent(const Uuid().v4(), 'title'),
      InbuiltComponents.prepareCompoent(const Uuid().v4(), 'text'),
    ]);
    navigation.addGroup(title: 'Booklet');
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
      _selectedComponent?.component.def.type == ComponentType.text;
  bool get selectedHasFocusBar =>
      _listStyleSelection.isNotEmpty &&
      _listStyleSelection.every((box) => box.hasFocusBar);

  void toggleFocusBarOnSelection() {
    if (theme.documentSettingsController.isReadOnly) return;
    final selection = _listStyleSelection;
    if (selection.isEmpty) return;
    final enable = !selectedHasFocusBar;
    for (final box in selection) {
      box.hasFocusBar = enable;
    }
    _documentChanged();
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

  NavigationNode addAssetsFolder() {
    clearSelectedComponent();
    final folder = navigation.addAssetsFolder(folderId: const Uuid().v4());
    _documentChanged();
    return folder;
  }

  void addPageBelowSelected() {
    _addPage(PagePlacement.below);
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

  void clearSelectedComponent() {
    for (final component in components) {
      component.isSelected = false;
      component.clearFocus();
    }
    _selectedComponent = null;
    _selectedComponents.clear();
    _anchorIndex = null;
  }

  ComponentBox createComponentBelow(int index, {TextSelection? selection}) {
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
    } else if (sourceListState != null && newState is ListItemComponentState) {
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
  }

  /// Splits [text] on newlines: the first line goes into the component at
  /// [index], each remaining line into a new component below. Returns the last
  /// component, or null when [text] has no newline (default paste applies).
  ComponentBox? pasteTextLines(int index, String text) {
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
  }

  void _ensureDeltaEndsWithNewline(List<Map<String, dynamic>> delta) {
    final lastInsert = delta.isEmpty ? null : delta.last['insert'];
    if (lastInsert is! String || !lastInsert.endsWith('\n')) {
      delta.add({'insert': '\n'});
    }
  }

  ComponentBox createComponentBelowType(int index, String type) {
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
  }

  void transformSelectedComponent(String type) {
    if (theme.documentSettingsController.isReadOnly) {
      return;
    }
    final selected = _selectedComponent;
    if (selected == null || !canTransformSelectedComponent) {
      return;
    }

    final oldComponent = selected.component;
    final newComponent = InbuiltComponents.prepareCompoent(
      oldComponent.id,
      type,
    );
    if (newComponent.def.type != ComponentType.text) {
      return;
    }

    newComponent.initialize(delta: oldComponent.textDelta);
    newComponent.state.isSelected = oldComponent.state.isSelected;
    selected.component = newComponent;
    _unwatchComponent(oldComponent.state);
    _watchComponent(selected);
    oldComponent.dispose();
    _documentChanged();
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
  }

  void deleteSelectedComponent() {
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
  }

  void dispose() {
    _unwatchAllComponents();
    for (final page in _pagesById.values) {
      page.dispose();
    }
  }

  void _watchPage(PageContent page) {
    for (final component in page.components) {
      _watchComponent(component);
    }
  }

  void _watchComponent(ComponentBox component) {
    final state = component.component.state;
    if (_componentListeners.containsKey(state)) return;
    final listener = _documentChanged;
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

  void _documentChanged() => onDocumentChanged?.call();
}
