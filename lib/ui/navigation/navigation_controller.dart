import 'navigation_models.dart';

class NavigationController {
  final List<NavigationNode> groups = [];
  String? selectedPageId;

  NavigationNode addGroup({String title = 'New group'}) {
    final group = NavigationNode.group(title: title);
    groups.add(group);
    return group;
  }

  void selectPage(String pageId) {
    if (_findNode((node) => node.pageId == pageId) != null) {
      selectedPageId = pageId;
    }
  }

  NavigationNode addPage({
    required String pageId,
    required String title,
    PagePlacement placement = PagePlacement.below,
    String? referencePageId,
  }) {
    final page = NavigationNode.page(title: title, pageId: pageId);
    final reference = referencePageId == null
        ? _selectedNode()
        : _findNode((node) => node.pageId == referencePageId);

    if (reference == null || reference.isGroup) {
      final group = reference?.isGroup == true
          ? reference!
          : (groups.isEmpty ? addGroup() : groups.first);
      group.children.add(page);
    } else if (placement == PagePlacement.child) {
      reference.children.add(page);
      reference.isExpanded = true;
    } else {
      final siblings = _siblingsOf(reference);
      final index = siblings.indexOf(reference);
      siblings.insert(
        placement == PagePlacement.above ? index : index + 1,
        page,
      );
    }

    selectedPageId = pageId;
    return page;
  }

  NavigationNode? _selectedNode() {
    final pageId = selectedPageId;
    return pageId == null ? null : _findNode((node) => node.pageId == pageId);
  }

  NavigationNode? _findNode(bool Function(NavigationNode node) test) {
    for (final group in groups) {
      final result = _findIn(group, test);
      if (result != null) {
        return result;
      }
    }
    return null;
  }

  NavigationNode? _findIn(
    NavigationNode node,
    bool Function(NavigationNode node) test,
  ) {
    if (test(node)) {
      return node;
    }
    for (final child in node.children) {
      final result = _findIn(child, test);
      if (result != null) {
        return result;
      }
    }
    return null;
  }

  List<NavigationNode> _siblingsOf(NavigationNode target) {
    for (final group in groups) {
      final siblings = _findParentChildren(group, target);
      if (siblings != null) {
        return siblings;
      }
    }
    return groups;
  }

  List<NavigationNode>? _findParentChildren(
    NavigationNode parent,
    NavigationNode target,
  ) {
    if (parent.children.contains(target)) {
      return parent.children;
    }
    for (final child in parent.children) {
      final result = _findParentChildren(child, target);
      if (result != null) {
        return result;
      }
    }
    return null;
  }
}
