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
  });
}
