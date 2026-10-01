import 'package:booklet/business/page_content.dart';
import 'package:booklet/business/components_business/component_def.dart';
import 'package:booklet/ui/components/component.dart';
import 'package:booklet/ui/components/inbuilt_components.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_snapshot.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:booklet/ui/navigation/navigation_panel_vm.dart';
import 'package:booklet/ui/navigation/navigation_node.dart';
import 'package:uuid/uuid.dart';

class BaseVM {
  BaseVM(this.theme, {bool createStarterPage = true}) {
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
  final NavigationPanelVM navigation = NavigationPanelVM();
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
  bool get canTransformSelectedComponent =>
      _selectedComponent?.component.def.type == ComponentType.text;
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
      InbuiltComponents.prepareCompoent(const Uuid().v4(), "text"),
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

  ComponentBox createComponentBelow(int index) {
    return createComponentBelowType(index, 'text');
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
