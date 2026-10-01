import 'package:flutter/material.dart';

class NavigationAddMenu extends StatelessWidget {
  const NavigationAddMenu({
    super.key,
    required this.onCreateGroup,
    required this.onAddPageBelow,
    required this.onAddChildPage,
    required this.onChanged,
  });

  final VoidCallback onCreateGroup;
  final VoidCallback onAddPageBelow;
  final VoidCallback onAddChildPage;
  final VoidCallback onChanged;

  void _runAction(NavigationAddAction action) {
    switch (action) {
      case NavigationAddAction.createGroup:
        onCreateGroup();
      case NavigationAddAction.addBelow:
        onAddPageBelow();
      case NavigationAddAction.addChild:
        onAddChildPage();
    }
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<NavigationAddAction>(
      tooltip: 'Add to navigation',
      icon: const Icon(Icons.add, size: 20),
      onSelected: _runAction,
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: NavigationAddAction.createGroup,
          child: ListTile(
            leading: Icon(Icons.view_list_outlined),
            title: Text('Create group'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: NavigationAddAction.addBelow,
          child: ListTile(
            leading: Icon(Icons.note_add_outlined),
            title: Text('Add page below'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: NavigationAddAction.addChild,
          child: ListTile(
            leading: Icon(Icons.account_tree_outlined),
            title: Text('Add child page'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

class NavigationMoreMenu extends StatelessWidget {
  const NavigationMoreMenu({
    super.key,
    required this.hasSelection,
    required this.onRename,
    required this.onDelete,
    required this.onChanged,
  });

  final bool hasSelection;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  void _runAction(NavigationMoreAction action) {
    switch (action) {
      case NavigationMoreAction.rename:
        onRename();
      case NavigationMoreAction.delete:
        onDelete();
    }
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<NavigationMoreAction>(
      enabled: hasSelection,
      tooltip: 'More navigation options',
      icon: const Icon(Icons.more_vert, size: 20),
      onSelected: _runAction,
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: NavigationMoreAction.rename,
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Rename'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: NavigationMoreAction.delete,
          child: ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('Delete'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

enum NavigationAddAction { createGroup, addBelow, addChild }

enum NavigationMoreAction { rename, delete }
