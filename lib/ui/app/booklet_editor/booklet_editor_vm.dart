import 'package:booklet/ui/app/components/components.dart';
import 'package:booklet/ui/app/editor_themes/editor_themes.dart';
import 'package:booklet/ui/app/navigation/navigation_controller.dart';
import 'package:booklet/ui/app/navigation/navigation_models.dart';

class PageContent {
  PageContent({
    required this.id,
    required this.title,
    required this.components,
  });

  final String id;
  String title;
  final List<ComponentBox> components;

  void dispose() {
    for (final component in components) {
      component.dispose();
    }
  }
}

class BookletEditorViewModel {
  BookletEditorViewModel(this.theme) {
    final starterPage = _createPage('Introduction', [
      TitleComponent(theme),
      TextComponent(theme),
      TextComponent(theme),
      HeadingComponent(theme),
      TextComponent(theme),
      TextComponent(theme),
      TextComponent(theme),
      TextComponent(theme),
      HeadingComponent(theme),
      TextComponent(theme),
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
  final NavigationController navigation = NavigationController();
  final Map<String, PageContent> _pagesById = {};
  int _nextId = 0;
  ComponentBox? _selectedComponent;
  String? _documentPath;

  PageContent? get selectedPage => navigation.selectedPageId == null
      ? null
      : _pagesById[navigation.selectedPageId];

  List<ComponentBox> get components => selectedPage?.components ?? [];
  ComponentBox? get selectedComponent => _selectedComponent;
  String? get selectedPageId => navigation.selectedPageId;
  String? get documentPath => _documentPath;

  void setDocumentPath(String? path) {
    _documentPath = path;
  }

  PageContent _createPage(String title, List<ComponentRenderer> renderers) {
    final id = 'page-${_nextId++}';
    return PageContent(
      id: id,
      title: title,
      components: [
        for (final renderer in renderers)
          ComponentBox(componentInfo: ComponentInfo(renderer: renderer)),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'navigation': navigation.groups.map((group) => group.toJson()).toList(),
    'selectedPageId': selectedPageId,
    'pages': [
      for (final page in _pagesById.values)
        {
          'id': page.id,
          'title': page.title,
          'components': [
            for (final component in page.components)
              {
                'type': component.componentInfo.renderer.name,
                'delta': component.component.controller.document
                    .toDelta()
                    .toJson(),
              },
          ],
        },
    ],
  };

  void loadJson(Map<String, dynamic> json) {
    final pageData = json['pages'];
    final navigationData = json['navigation'];
    if (pageData is! List || navigationData is! List) {
      throw const FormatException('Invalid booklet document structure');
    }

    for (final page in _pagesById.values) {
      page.dispose();
    }
    _pagesById.clear();
    _selectedComponent = null;

    for (final rawPage in pageData.whereType<Map>()) {
      final pageJson = Map<String, dynamic>.from(rawPage);
      final id = pageJson['id'] as String?;
      if (id == null || id.isEmpty) {
        continue;
      }
      final components = <ComponentBox>[];
      final rawComponents = pageJson['components'];
      if (rawComponents is List) {
        for (final rawComponent in rawComponents.whereType<Map>()) {
          final componentJson = Map<String, dynamic>.from(rawComponent);
          final type = componentJson['type'] as String?;
          final delta = componentJson['delta'];
          if (type == null || delta is! List) {
            continue;
          }
          components.add(
            ComponentBox(
              componentInfo: ComponentInfo(
                renderer: ComponentRenderer.fromType(type, theme),
              ),
              delta: delta,
            ),
          );
        }
      }
      _pagesById[id] = PageContent(
        id: id,
        title: pageJson['title'] as String? ?? 'Untitled page',
        components: components,
      );
    }

    navigation.replaceGroups(
      navigationData
          .whereType<Map>()
          .map(
            (group) =>
                NavigationNode.fromJson(Map<String, dynamic>.from(group)),
          )
          .toList(),
      selectedPageId: json['selectedPageId'] as String?,
    );
    _nextId = _pagesById.length;
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
      componentInfo: ComponentInfo(
        renderer: ComponentRenderer.fromType(type, theme),
      ),
    );
    page.components.insert(index + 1, component);
    _selectedComponent = component;
    return component;
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
    final page = _createPage('Untitled page', [TextComponent(theme)]);
    navigation.addPage(
      pageId: page.id,
      title: page.title,
      placement: placement,
    );
    _pagesById[page.id] = page;
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

  void transformSelectedComponent(String type) {
    final selected = _selectedComponent;
    if (selected == null) {
      return;
    }
    selected.componentInfo.renderer = ComponentRenderer.fromType(type, theme);
  }

  void dispose() {
    for (final page in _pagesById.values) {
      page.dispose();
    }
  }
}
