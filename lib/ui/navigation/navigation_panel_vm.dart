import 'navigation_node.dart';

class NavigationPanelVM {
  final List<NavigationNode> groups = [];
  NavigationNode? selectedNode;
  String? selectedPageId;
  String? selectedAssetFolderId;

  void replaceGroups(
    List<NavigationNode> nodes, {
    String? selectedPageId,
    String? selectedAssetFolderId,
  }) {
    groups
      ..clear()
      ..addAll(nodes);
    this.selectedPageId = selectedPageId;
    selectedNode = selectedAssetFolderId == null
        ? (selectedPageId == null
              ? null
              : _findNode((node) => node.pageId == selectedPageId))
        : _findNode((node) => node.folderId == selectedAssetFolderId);
    this.selectedAssetFolderId = selectedNode?.folderId;
  }

  NavigationNode addGroup({String title = 'New group'}) {
    final group = NavigationNode.group(title: title);
    groups.add(group);
    return group;
  }

  void selectPage(String pageId) {
    final page = _findNode((node) => node.pageId == pageId);
    if (page != null) {
      selectNode(page);
    }
  }

  void selectNode(NavigationNode node) {
    if (_findNode((candidate) => candidate == node) == null) {
      return;
    }
    selectedNode = node;
    if (node.isPage) {
      selectedPageId = node.pageId;
    }
    selectedAssetFolderId = node.isAssetsFolder ? node.folderId : null;
  }

  NavigationNode addAssetsFolder({
    required String folderId,
    String title = 'Assets',
  }) {
    final folder = NavigationNode.assetsFolder(
      title: title,
      folderId: folderId,
    );
    final reference = selectedNode ?? _selectedNode();
    if (reference == null || reference.isGroup) {
      final group = reference?.isGroup == true
          ? reference!
          : (groups.isEmpty ? addGroup() : groups.first);
      group.children.add(folder);
    } else if (reference.isPage) {
      reference.children.add(folder);
      reference.isExpanded = true;
    } else {
      final siblings = _siblingsOf(reference);
      final index = siblings.indexOf(reference);
      siblings.insert(index + 1, folder);
    }
    selectNode(folder);
    return folder;
  }

  NavigationNode? renamePage(String pageId, String title) {
    final page = _findNode((node) => node.pageId == pageId);
    return page == null || page.isGroup ? null : renameNode(page, title);
  }

  NavigationNode? renameNode(NavigationNode node, String title) {
    if (_findNode((candidate) => candidate == node) == null) {
      return null;
    }
    node.title = title;
    return node;
  }

  NavigationNode? deleteNode(NavigationNode node) {
    if (_findNode((candidate) => candidate == node) == null) {
      return null;
    }

    final siblings = _siblingsOf(node);
    final index = siblings.indexOf(node);
    final removedSelectionIds = <String>{};
    _collectSelectionIds(node, removedSelectionIds);
    siblings.removeAt(index);
    if (selectedNode == node ||
        removedSelectionIds.contains(selectedPageId) ||
        removedSelectionIds.contains(selectedAssetFolderId)) {
      final selectedExistingNode = selectedPageId == null
          ? null
          : _findNode((candidate) => candidate.pageId == selectedPageId);
      selectedNode =
          selectedExistingNode ??
          _selectableNear(siblings, index) ??
          _findNode(
            (candidate) => candidate.isPage || candidate.isAssetsFolder,
          );
      selectedPageId = selectedNode?.isPage == true
          ? selectedNode?.pageId
          : null;
      selectedAssetFolderId = selectedNode?.folderId;
    }
    return node;
  }

  void _collectSelectionIds(NavigationNode node, Set<String> selectionIds) {
    final pageId = node.pageId;
    if (pageId != null) {
      selectionIds.add(pageId);
    }
    final folderId = node.folderId;
    if (folderId != null) {
      selectionIds.add(folderId);
    }
    for (final child in node.children) {
      _collectSelectionIds(child, selectionIds);
    }
  }

  NavigationNode? _selectableNear(List<NavigationNode> siblings, int index) {
    for (
      var siblingIndex = index;
      siblingIndex < siblings.length;
      siblingIndex++
    ) {
      final selectable = _firstSelectableIn(siblings[siblingIndex]);
      if (selectable != null) {
        return selectable;
      }
    }
    for (var siblingIndex = index - 1; siblingIndex >= 0; siblingIndex--) {
      final selectable = _firstSelectableIn(siblings[siblingIndex]);
      if (selectable != null) {
        return selectable;
      }
    }
    return null;
  }

  NavigationNode? _firstSelectableIn(NavigationNode node) {
    if (node.isPage || node.isAssetsFolder) {
      return node;
    }
    for (final child in node.children) {
      final selectable = _firstSelectableIn(child);
      if (selectable != null) {
        return selectable;
      }
    }
    return null;
  }

  NavigationNode addPage({
    required String pageId,
    required String title,
    PagePlacement placement = PagePlacement.below,
    String? referencePageId,
  }) {
    final page = NavigationNode.page(title: title, pageId: pageId);
    final reference = referencePageId == null
        ? selectedNode ?? _selectedNode()
        : _findNode((node) => node.pageId == referencePageId);

    if (reference == null || reference.isGroup) {
      final group = reference?.isGroup == true
          ? reference!
          : (groups.isEmpty ? addGroup() : groups.first);
      group.children.add(page);
    } else if (placement == PagePlacement.child && reference.isPage) {
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
    selectedNode = page;
    selectedAssetFolderId = null;
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
