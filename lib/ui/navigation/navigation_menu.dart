import 'package:flutter/material.dart';

class NavigationMenu extends StatelessWidget {
  const NavigationMenu({
    super.key,
    required this.onCreateGroup,
    required this.onAddPageBelow,
    required this.onAddChildPage,
    required this.onAddPageAbove,
    required this.onRename,
    required this.onDelete,
    required this.onChanged,
  });

  final VoidCallback onCreateGroup;
  final VoidCallback onAddPageBelow;
  final VoidCallback onAddChildPage;
  final VoidCallback onAddPageAbove;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  void _runAction(NavigationAction action) {
    switch (action) {
      case NavigationAction.createGroup:
        onCreateGroup();
      case NavigationAction.addBelow:
        onAddPageBelow();
      case NavigationAction.addChild:
        onAddChildPage();
      case NavigationAction.addAbove:
        onAddPageAbove();
      case NavigationAction.rename:
        onRename();
      case NavigationAction.delete:
        onDelete();
    }
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<NavigationAction>(
      tooltip: 'Navigation actions',
      icon: const Icon(Icons.add, size: 20),
      onSelected: _runAction,
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: NavigationAction.createGroup,
          child: ListTile(
            leading: Icon(Icons.view_list_outlined),
            title: Text('Create group'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: NavigationAction.addBelow,
          child: ListTile(
            leading: Icon(Icons.note_add_outlined),
            title: Text('Add page below'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: NavigationAction.addChild,
          child: ListTile(
            leading: Icon(Icons.account_tree_outlined),
            title: Text('Add child page'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: NavigationAction.addAbove,
          child: ListTile(
            leading: Icon(Icons.note_add_outlined),
            title: Text('Add page above'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: NavigationAction.rename,
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Rename item'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: NavigationAction.delete,
          child: ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('Delete page'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

enum NavigationAction {
  createGroup,
  addBelow,
  addChild,
  addAbove,
  rename,
  delete,
}
