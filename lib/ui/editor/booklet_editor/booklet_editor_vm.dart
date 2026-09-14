import 'package:booklet/ui/editor/components/components.dart';
import 'package:booklet/ui/editor/editor_themes/editor_themes.dart';
import 'package:booklet/ui/navigation/navigation_controller.dart';
import 'package:booklet/ui/navigation/navigation_models.dart';

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

  PageContent? get selectedPage => navigation.selectedPageId == null
      ? null
      : _pagesById[navigation.selectedPageId];

  List<ComponentBox> get components => selectedPage?.components ?? [];
  ComponentBox? get selectedComponent => _selectedComponent;
  String? get selectedPageId => navigation.selectedPageId;

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

  void selectPage(String pageId) {
    navigation.selectPage(pageId);
    _selectedComponent = null;
  }

  void selectComponent(ComponentBox component) {
    if (components.contains(component)) {
      _selectedComponent = component;
    }
  }

  ComponentBox createComponentBelow(int index) {
    return createComponentBelowType(index, 'Text');
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

  void _addPage(PagePlacement placement) {
    final page = _createPage('Untitled page', [TextComponent(theme)]);
    navigation.addPage(
      pageId: page.id,
      title: page.title,
      placement: placement,
    );
    _pagesById[page.id] = page;
    _selectedComponent = null;
  }

  void deleteSelectedComponent() {
    final page = selectedPage;
    final selected = _selectedComponent;
    if (page == null || selected == null) {
      return;
    }
    if (page.components.remove(selected)) {
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
