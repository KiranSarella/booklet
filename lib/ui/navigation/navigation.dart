import 'package:flutter/material.dart';

import 'navigation_controller.dart';
import 'navigation_models.dart';

class BookletNavigation extends StatefulWidget {
  const BookletNavigation({
    super.key,
    required this.controller,
    required this.onPageSelected,
    required this.onCreateGroup,
    required this.onAddPageBelow,
    required this.onAddChildPage,
    required this.onAddPageAbove,
    required this.onChanged,
  });

  final NavigationController controller;
  final ValueChanged<NavigationNode> onPageSelected;
  final VoidCallback onCreateGroup;
  final VoidCallback onAddPageBelow;
  final VoidCallback onAddChildPage;
  final VoidCallback onAddPageAbove;
  final VoidCallback onChanged;

  @override
  State<BookletNavigation> createState() => _BookletNavigationState();
}

class _BookletNavigationState extends State<BookletNavigation> {
  void _runAction(_NavigationAction action) {
    switch (action) {
      case _NavigationAction.createGroup:
        widget.onCreateGroup();
      case _NavigationAction.addBelow:
        widget.onAddPageBelow();
      case _NavigationAction.addChild:
        widget.onAddChildPage();
      case _NavigationAction.addAbove:
        widget.onAddPageAbove();
    }
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 272,
      color: const Color(0xFFF7F7F5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 12, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Booklet',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                PopupMenuButton<_NavigationAction>(
                  tooltip: 'Add to navigation',
                  icon: const Icon(Icons.add, size: 20),
                  onSelected: _runAction,
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _NavigationAction.createGroup,
                      child: ListTile(
                        leading: Icon(Icons.view_list_outlined),
                        title: Text('Create group'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: _NavigationAction.addBelow,
                      child: ListTile(
                        leading: Icon(Icons.note_add_outlined),
                        title: Text('Add page below'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: _NavigationAction.addChild,
                      child: ListTile(
                        leading: Icon(Icons.account_tree_outlined),
                        title: Text('Add child page'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: _NavigationAction.addAbove,
                      child: ListTile(
                        leading: Icon(Icons.note_add_outlined),
                        title: Text('Add page above'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                for (final group in widget.controller.groups)
                  _NavigationBranch(
                    node: group,
                    depth: 0,
                    selectedPageId: widget.controller.selectedPageId,
                    onSelected: widget.onPageSelected,
                    onChanged: () => setState(() {}),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationBranch extends StatelessWidget {
  const _NavigationBranch({
    required this.node,
    required this.depth,
    required this.selectedPageId,
    required this.onSelected,
    required this.onChanged,
  });

  final NavigationNode node;
  final int depth;
  final String? selectedPageId;
  final ValueChanged<NavigationNode> onSelected;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final hasChildren = node.children.isNotEmpty;
    final canExpand = !node.isGroup && hasChildren;
    final isSelected = node.pageId == selectedPageId;

    return Padding(
      padding: EdgeInsets.only(
        top: node.isGroup ? 8 : 0,
        bottom: node.isGroup ? 10 : 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => onSelected(node),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              padding: EdgeInsets.only(
                left: 8.0 + depth * 18,
                right: 8,
                top: 7,
                bottom: 7,
              ),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFE3E8FF) : null,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: node.isGroup ? 0 : 20,
                    child: canExpand
                        ? IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            splashRadius: 16,
                            tooltip: node.isExpanded ? 'Collapse' : 'Expand',
                            icon: Icon(
                              node.isExpanded
                                  ? Icons.expand_more
                                  : Icons.chevron_right,
                              size: 18,
                            ),
                            onPressed: () {
                              node.isExpanded = !node.isExpanded;
                              onChanged();
                            },
                          )
                        : null,
                  ),
                  Icon(node.icon, size: 18, color: Colors.grey.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      node.title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: node.isGroup
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: const Color(0xFF292929),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (node.isGroup || node.isExpanded)
            for (final child in node.children)
              _NavigationBranch(
                node: child,
                depth: depth + 1,
                selectedPageId: selectedPageId,
                onSelected: onSelected,
                onChanged: onChanged,
              ),
        ],
      ),
    );
  }
}

enum _NavigationAction { createGroup, addBelow, addChild, addAbove }
