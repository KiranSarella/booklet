import 'package:flutter/material.dart';

class NavigationAddMenu extends StatelessWidget {
  const NavigationAddMenu({
    super.key,
    required this.onCreateGroup,
    required this.onAddPageBelow,
    required this.onAddChildPage,
    required this.onAddAssetsFolderBelow,
    required this.onAddAssetsFolderInside,
    required this.canAddChildPage,
    required this.onChanged,
  });

  final VoidCallback onCreateGroup;
  final VoidCallback onAddPageBelow;
  final VoidCallback onAddChildPage;
  final VoidCallback onAddAssetsFolderBelow;
  final VoidCallback onAddAssetsFolderInside;
  final bool canAddChildPage;
  final VoidCallback onChanged;

  void _runAction(NavigationAddAction action) {
    switch (action) {
      case NavigationAddAction.createGroup:
        onCreateGroup();
      case NavigationAddAction.addBelow:
        onAddPageBelow();
      case NavigationAddAction.addChild:
        onAddChildPage();
      case NavigationAddAction.addAssetsFolderBelow:
        onAddAssetsFolderBelow();
      case NavigationAddAction.addAssetsFolderInside:
        onAddAssetsFolderInside();
    }
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<NavigationAddAction>(
      tooltip: 'Add to navigation',
      icon: const Icon(Icons.add, size: 20),
      onSelected: _runAction,
      itemBuilder: (context) => [
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
          enabled: canAddChildPage,
          child: ListTile(
            leading: Icon(Icons.account_tree_outlined),
            title: Text('Add child page'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: NavigationAddAction.addAssetsFolderBelow,
          child: ListTile(
            leading: Icon(Icons.create_new_folder_outlined),
            title: Text('Add assets folder below'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: NavigationAddAction.addAssetsFolderInside,
          enabled: canAddChildPage,
          child: ListTile(
            leading: Icon(Icons.create_new_folder_outlined),
            title: Text('Add assets folder inside'),
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
    required this.canPaste,
    required this.onDuplicate,
    required this.onCopy,
    required this.onPaste,
    required this.onRename,
    required this.onDelete,
    required this.onChanged,
  });

  final bool hasSelection;
  final bool canPaste;
  final VoidCallback onDuplicate;
  final VoidCallback onCopy;
  final VoidCallback onPaste;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  void _runAction(NavigationMoreAction action) {
    switch (action) {
      case NavigationMoreAction.duplicate:
        onDuplicate();
      case NavigationMoreAction.copy:
        onCopy();
      case NavigationMoreAction.paste:
        onPaste();
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
      tooltip: 'More navigation options',
      icon: const Icon(Icons.more_vert, size: 20),
      onSelected: _runAction,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: NavigationMoreAction.duplicate,
          enabled: hasSelection && canPaste,
          child: const ListTile(
            leading: Icon(Icons.content_copy_outlined),
            title: Text('Duplicate'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: NavigationMoreAction.copy,
          enabled: hasSelection,
          child: const ListTile(
            leading: Icon(Icons.copy_all_outlined),
            title: Text('Copy'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: NavigationMoreAction.paste,
          enabled: canPaste,
          child: const ListTile(
            leading: Icon(Icons.content_paste_outlined),
            title: Text('Paste'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: NavigationMoreAction.rename,
          enabled: hasSelection,
          child: const ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Rename'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: NavigationMoreAction.delete,
          enabled: hasSelection,
          child: const ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('Delete'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

enum NavigationAddAction {
  createGroup,
  addBelow,
  addChild,
  addAssetsFolderBelow,
  addAssetsFolderInside,
}

enum NavigationMoreAction { duplicate, copy, paste, rename, delete }
