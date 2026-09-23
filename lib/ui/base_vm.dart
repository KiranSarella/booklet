import 'package:booklet/business/page_content.dart';
import 'package:booklet/ui/components/component.dart';
import 'package:booklet/ui/components/inbuilt_component_objects.dart';
import 'package:booklet/ui/components/inbuilt_components.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/editor_themes/editor_themes.dart';
import 'package:booklet/ui/navigation/navigation_panel_vm.dart';
import 'package:booklet/ui/navigation/navigation_node.dart';
import 'package:uuid/uuid.dart';

class BaseVM {
  BaseVM(this.theme, {bool createStarterPage = true}) {
    if (!createStarterPage) {
      return;
    }

    final starterPage = _createPage('Introduction', [
      InbuiltComponents.prepareCompoent(Uuid().toString(), 'title'),
      InbuiltComponents.prepareCompoent(Uuid().toString(), 'text'),
    ]);
    navigation.addGroup(title: 'Booklet');
    navigation.addPage(
      pageId: starterPage.id,
      title: starterPage.title,
      referencePageId: null,
    );
    _pagesById[starterPage.id] = starterPage;
    navigation.selectPage(starterPage.id);
  }

  final EditorTheme theme;
  final NavigationPanelVM navigation = NavigationPanelVM();
  final Map<String, PageContent> _pagesById = {};
  ComponentBox? _selectedComponent;
  String? _documentPath;

  PageContent? get selectedPage => navigation.selectedPageId == null
      ? null
      : _pagesById[navigation.selectedPageId];

  List<ComponentBox> get components => selectedPage?.components ?? [];
  Iterable<PageContent> get loadedPages => _pagesById.values;
  ComponentBox? get selectedComponent => _selectedComponent;
  String? get selectedPageId => navigation.selectedPageId;
  String? get documentPath => _documentPath;

  void replaceNavigation(
    List<NavigationNode> groups, {
    String? selectedPageId,
  }) {
    navigation.replaceGroups(groups, selectedPageId: selectedPageId);
    _selectedComponent = null;
  }

  void setSelectedPage(PageContent page) {
    for (final loadedPage in _pagesById.values) {
      if (loadedPage.id != page.id) {
        loadedPage.dispose();
      }
    }
    _pagesById
      ..clear()
      ..[page.id] = page;
    navigation.selectPage(page.id);
    _selectedComponent = null;
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
        for (final component in components)
          ComponentBox(component: component)
      ],
    );
  }

  void selectPage(String pageId) {
    navigation.selectPage(pageId);
    _selectedComponent = null;
  }

  void selectNode(NavigationNode node) {
    navigation.selectNode(node);
    if (node.isPage) {
      clearSelectedComponent();
    }
  }

  void addGroup() {
    navigation.addGroup();
  }

  void addPageBelowSelected() {
    _addPage(PagePlacement.below);
  }

  void addChildPageSelected() {
    _addPage(PagePlacement.child);
  }

  void addPageAboveSelected() {
    _addPage(PagePlacement.above);
  }

  void renameSelectedPage(String title) {
    final selectedNode = navigation.selectedNode;
    if (selectedNode == null) {
      return;
    }
    final node = navigation.renameNode(selectedNode, title.trim());
    final pageId = node?.pageId;
    if (pageId != null) {
      _pagesById[pageId]?.title = node!.title;
    }
  }

  void deleteSelectedPage() {
    final selectedNode = navigation.selectedNode;
    final pageId = selectedNode?.pageId;
    if (selectedNode == null || selectedNode.isGroup || pageId == null) {
      return;
    }
    final page = navigation.deletePage(pageId);
    if (page == null) {
      return;
    }
    clearSelectedComponent();
    _pagesById.remove(pageId)?.dispose();
  }

  void _addPage(PagePlacement placement) {
    clearSelectedComponent();
    final page = _createPage('Untitled page', [InbuiltComponents.prepareCompoent(Uuid().toString(), "text")]);
    navigation.addPage(
      pageId: page.id,
      title: page.title,
      placement: placement,
    );
    _pagesById[page.id] = page;
  }

  // MARK: - Components

  void selectComponent(ComponentBox component) {
    if (components.contains(component)) {
      for (final item in components) {
        item.isSelected = false;
      }
      component.isSelected = true;
      _selectedComponent = component;
    }
  }

  void clearSelectedComponent() {
    for (final component in components) {
      component.isSelected = false;
    }
    _selectedComponent = null;
  }

  ComponentBox createComponentBelow(int index) {
    return createComponentBelowType(index, 'text');
  }

  ComponentBox createComponentBelowType(int index, String type) {
    final page = selectedPage;
    if (page == null) {
      throw StateError('No page is selected');
    }
    final component = ComponentBox(
      component: InbuiltComponents.prepareCompoent(const Uuid().v4(), type),
    );
    page.components.insert(index + 1, component);
    _selectedComponent = component;
    return component;
  }


  void transformSelectedComponent(String type) {
    final selected = _selectedComponent;
    if (selected == null) {
      return;
    }
    selected.component = InbuiltComponents.prepareCompoent(selected.component.id, type);
  }


  void deleteSelectedComponent() {
    final page = selectedPage;
    final selected = _selectedComponent;
    if (page == null || selected == null) {
      return;
    }
    if (page.components.remove(selected)) {
      selected.isSelected = false;
      selected.dispose();
      _selectedComponent = null;
    }
  }


  void dispose() {
    for (final page in _pagesById.values) {
      page.dispose();
    }
  }
}
