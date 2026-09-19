import 'package:booklet/ui/components/components.dart';

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
