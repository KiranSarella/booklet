import 'navigation_node.dart';

import 'package:booklet/business/booklet_asset.dart';
import 'package:uuid/uuid.dart';

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
    final normalizedNodes = <NavigationNode>[];
    NavigationNode? looseItemsGroup;
    for (final node in nodes) {
      if (node.isGroup) {
        normalizedNodes.add(node);
      } else {
        looseItemsGroup ??= NavigationNode.group(title: 'New group');
        if (!normalizedNodes.contains(looseItemsGroup)) {
          normalizedNodes.add(looseItemsGroup);
        }
        looseItemsGroup.children.add(node);
      }
    }
    groups
      ..clear()
      ..addAll(normalizedNodes);
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

  NavigationNode? duplicateNode(NavigationNode node) {
    final siblings = _siblingsContaining(node);
    if (siblings == null) {
      return null;
    }

    final duplicate = _copyNode(node);
    siblings.insert(siblings.indexOf(node) + 1, duplicate);
    selectedNode = duplicate;
    if (duplicate.isPage) {
      selectedPageId = duplicate.pageId;
    }
    selectedAssetFolderId = duplicate.folderId;
    return duplicate;
  }

  bool canMoveNode(
    NavigationNode source,
    NavigationNode target, {
    required bool into,
  }) {
    if (identical(source, target) ||
        _siblingsContaining(source) == null ||
        _siblingsContaining(target) == null) {
      return false;
    }
    if (source.isGroup) {
      return target.isGroup && !into && !_containsNode(source, target);
    }
    if (!source.isPage) {
      return false;
    }
    if (target.isGroup) {
      return into;
    }
    if (!target.isPage) {
      return false;
    }
    return !into || !_containsNode(source, target);
  }

  bool moveNode(
    NavigationNode source,
    NavigationNode target, {
    bool before = false,
    bool into = false,
  }) {
    if (!canMoveNode(source, target, into: into)) {
      return false;
    }

    final sourceSiblings = _siblingsOf(source);
    final destination = into
        ? target.children
        : target.isGroup
        ? groups
        : _siblingsOf(target);
    if (into && destination.contains(source)) {
      return false;
    }

    sourceSiblings.remove(source);
    if (into) {
      if (target.isGroup && before) {
        destination.insert(0, source);
      } else {
        destination.add(source);
      }
      target.isExpanded = true;
    } else {
      final targetIndex = destination.indexOf(target);
      destination.insert(targetIndex + (before ? 0 : 1), source);
    }
    return true;
  }

  NavigationNode? pasteNode(NavigationNode node) {
    final duplicate = _copyNode(node);
    final selected = selectedNode;
    if (duplicate.isGroup) {
      if (selected == null) {
        groups.add(duplicate);
      } else {
        final siblings = _siblingsOf(selected);
        siblings.insert(siblings.indexOf(selected) + 1, duplicate);
      }
    } else if (selected?.isGroup == true) {
      selected!.children.add(duplicate);
      selected.isExpanded = true;
    } else if (selected == null) {
      final group = groups.isEmpty ? addGroup() : groups.first;
      group.children.add(duplicate);
      group.isExpanded = true;
    } else {
      final siblings = _siblingsOf(selected);
      siblings.insert(siblings.indexOf(selected) + 1, duplicate);
    }
    selectedNode = duplicate;
    selectedPageId = duplicate.isPage ? duplicate.pageId : selectedPageId;
    selectedAssetFolderId = duplicate.folderId;
    return duplicate;
  }

  NavigationNode _copyNode(NavigationNode source) {
    final copy = source.isGroup
        ? NavigationNode.group(title: source.title)
        : source.isPage
        ? NavigationNode.page(title: source.title, pageId: const Uuid().v4())
        : NavigationNode.assetsFolder(
            title: source.title,
            folderId: const Uuid().v4(),
          );
    copy.isExpanded = source.isExpanded;
    copy.assets.addAll(
      source.assets.map(
        (asset) => BookletAsset(
          id: const Uuid().v4(),
          name: asset.name,
          path: asset.path,
        ),
      ),
    );
    copy.children.addAll(source.children.map(_copyNode));
    return copy;
  }

  List<NavigationNode>? _siblingsContaining(NavigationNode target) {
    if (groups.contains(target)) {
      return groups;
    }
    for (final group in groups) {
      final siblings = _findParentChildren(group, target);
      if (siblings != null) {
        return siblings;
      }
    }
    return null;
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

  bool _containsNode(NavigationNode root, NavigationNode candidate) {
    if (identical(root, candidate)) {
      return true;
    }
    return root.children.any((child) => _containsNode(child, candidate));
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
