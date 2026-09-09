import 'package:booklet/ui/editor/components/components.dart';
import 'package:booklet/ui/editor/editor_themes/editor_themes.dart';

class BookletEditorViewModel {
  BookletEditorViewModel(this.theme)
    : components = [
        ComponentBox(
          componentInfo: ComponentInfo(renderer: TitleComponent(theme)),
        ),
        ComponentBox(
          componentInfo: ComponentInfo(renderer: TextComponent(theme)),
        ),
        ComponentBox(
          componentInfo: ComponentInfo(renderer: TextComponent(theme)),
        ),
        ComponentBox(
          componentInfo: ComponentInfo(renderer: HeadingComponent(theme)),
        ),
        ComponentBox(
          componentInfo: ComponentInfo(renderer: TextComponent(theme)),
        ),
        ComponentBox(
          componentInfo: ComponentInfo(renderer: TextComponent(theme)),
        ),
        ComponentBox(
          componentInfo: ComponentInfo(renderer: TextComponent(theme)),
        ),
        ComponentBox(
          componentInfo: ComponentInfo(renderer: TextComponent(theme)),
        ),
        ComponentBox(
          componentInfo: ComponentInfo(renderer: HeadingComponent(theme)),
        ),
        ComponentBox(
          componentInfo: ComponentInfo(renderer: TextComponent(theme)),
        ),
      ];

  final EditorTheme theme;
  final List<ComponentBox> components;
  int _selectedIndex = 0;

  ComponentBox get selectedComponent => components[_selectedIndex];

  void selectComponent(int index) {
    _selectedIndex = index;
  }

  ComponentBox createComponentBelow(int index) {
    return createComponentBelowType(index, 'Text');
  }

  ComponentBox createComponentBelowType(int index, String type) {
    final component = ComponentBox(
      componentInfo: ComponentInfo(
        renderer: ComponentRenderer.fromType(type, theme),
      ),
    );
    components.insert(index + 1, component);
    _selectedIndex = index + 1;
    return component;
  }

  void dispose() {
    for (final component in components) {
      component.dispose();
    }
  }
}

/*
class BookletEditorViewModel {
  final List<BookletComponent> components = [BookletComponent()];
  int _selectedIndex = 0;

  BookletComponent get selectedComponent => components[_selectedIndex];

  void selectComponent(int index) {
    _selectedIndex = index;
  }

  BookletComponent createComponentBelow(int index) {
    final component = BookletComponent();
    components.insert(index + 1, component);
    _selectedIndex = index + 1;
    return component;
  }

  void dispose() {
    for (final component in components) {
      component.dispose();
    }
  }
}

*/
