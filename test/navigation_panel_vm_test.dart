import 'package:booklet/business/booklet_asset.dart';
import 'package:booklet/ui/navigation/navigation_node.dart';
import 'package:booklet/ui/navigation/navigation_panel_vm.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NavigationPanelVM selected-node actions', () {
    test('renames a selected group', () {
      final navigation = NavigationPanelVM();
      final group = navigation.addGroup(title: 'Old group');
      navigation.selectNode(group);

      final renamed = navigation.renameNode(group, 'New group');

      expect(renamed, same(group));
      expect(group.title, 'New group');
    });

    test('deletes a selected group and selects a surviving page', () {
      final navigation = NavigationPanelVM();
      final removedGroup = navigation.addGroup(title: 'Group to delete');
      final removedPage = NavigationNode.page(
        title: 'Page to delete',
        pageId: 'removed-page',
      );
      removedGroup.children.add(removedPage);
      final remainingGroup = navigation.addGroup(title: 'Remaining group');
      final remainingPage = NavigationNode.page(
        title: 'Remaining page',
        pageId: 'remaining-page',
      );
      remainingGroup.children.add(remainingPage);
      navigation.selectPage(removedPage.pageId!);
      navigation.selectNode(removedGroup);

      final deleted = navigation.deleteNode(removedGroup);

      expect(deleted, same(removedGroup));
      expect(navigation.groups, [remainingGroup]);
      expect(navigation.selectedNode, same(remainingPage));
      expect(navigation.selectedPageId, remainingPage.pageId);
    });

    test('duplicates a subtree with fresh page, folder, and asset IDs', () {
      final navigation = NavigationPanelVM();
      final group = navigation.addGroup(title: 'Research');
      final page = NavigationNode.page(title: 'Notes', pageId: 'page-original');
      final folder = NavigationNode.assetsFolder(
        title: 'Sources',
        folderId: 'folder-original',
      );
      folder.assets.add(
        const BookletAsset(
          id: 'asset-original',
          name: 'paper.pdf',
          path: 'assets/folder-original/asset-original.pdf',
        ),
      );
      page.children.add(folder);
      group.children.add(page);
      navigation.selectNode(group);

      final duplicate = navigation.duplicateNode(group)!;
      final copiedPage = duplicate.children.single;
      final copiedFolder = copiedPage.children.single;

      expect(duplicate.title, group.title);
      expect(copiedPage.title, page.title);
      expect(copiedPage.pageId, isNot(page.pageId));
      expect(copiedFolder.folderId, isNot(folder.folderId));
      expect(copiedFolder.assets.single.id, isNot(folder.assets.single.id));
      expect(copiedFolder.assets.single.name, 'paper.pdf');
      expect(navigation.groups, [group, duplicate]);
      expect(navigation.selectedNode, same(duplicate));
    });

    test('pastes a page at the end of the selected group', () {
      final navigation = NavigationPanelVM();
      final group = navigation.addGroup(title: 'Research');
      final existingPage = NavigationNode.page(
        title: 'Existing page',
        pageId: 'existing-page',
      );
      group.children.add(existingPage);
      navigation.selectNode(group);
      final copiedPage = NavigationNode.page(
        title: 'Copied page',
        pageId: 'copied-page',
      );

      final pasted = navigation.pasteNode(copiedPage)!;

      expect(navigation.groups, [group]);
      expect(navigation.groups.every((node) => node.isGroup), isTrue);
      expect(group.children, [existingPage, pasted]);
      expect(pasted.isPage, isTrue);
      expect(pasted.pageId, isNot(copiedPage.pageId));
      expect(navigation.selectedNode, same(pasted));
    });

    test('wraps legacy root pages in a group when loading navigation', () {
      final loosePage = NavigationNode.page(
        title: 'Legacy page',
        pageId: 'legacy-page',
      );
      final existingGroup = NavigationNode.group(title: 'Existing group');
      final navigation = NavigationPanelVM();

      navigation.replaceGroups([
        loosePage,
        existingGroup,
      ], selectedPageId: loosePage.pageId);

      expect(navigation.groups, hasLength(2));
      expect(navigation.groups.every((node) => node.isGroup), isTrue);
      expect(navigation.groups.first.children, [loosePage]);
      expect(navigation.selectedNode, same(loosePage));
    });

    test('adds an asset folder under a selected page and keeps it a leaf', () {
      final navigation = NavigationPanelVM();
      final group = navigation.addGroup(title: 'Group');
      final page = navigation.addPage(
        pageId: 'parent-page',
        title: 'Parent page',
      );
      navigation.selectNode(page);

      final folder = navigation.addAssetsFolder(folderId: 'folder-1');
      final siblingPage = navigation.addPage(
        pageId: 'sibling-page',
        title: 'Sibling page',
        placement: PagePlacement.child,
      );

      expect(group.children, [page]);
      expect(page.children, [folder, siblingPage]);
      expect(folder.children, isEmpty);
      expect(navigation.selectedNode, same(siblingPage));
      expect(navigation.selectedAssetFolderId, isNull);
    });

    test('round-trips asset folders and ignores serialized child nodes', () {
      final folder =
          NavigationNode.assetsFolder(
              title: 'Reference files',
              folderId: 'folder-1',
            )
            ..assets.add(
              const BookletAsset(
                id: 'asset-1',
                name: 'diagram.png',
                path: 'assets/folder-1/asset-1.png',
              ),
            );
      final json = folder.toJson()
        ..['children'] = [
          NavigationNode.page(
            title: 'Invalid child',
            pageId: 'child-page',
          ).toJson(),
        ];

      final restored = NavigationNode.fromJson(json);

      expect(restored.isAssetsFolder, isTrue);
      expect(restored.folderId, 'folder-1');
      expect(restored.assets.single.name, 'diagram.png');
      expect(restored.children, isEmpty);
    });
  });
}
