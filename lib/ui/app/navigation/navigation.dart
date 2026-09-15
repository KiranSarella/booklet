import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    required this.onRenamePage,
    required this.onDeletePage,
    required this.onChanged,
  });

  final NavigationController controller;
  final ValueChanged<NavigationNode> onPageSelected;
  final VoidCallback onCreateGroup;
  final VoidCallback onAddPageBelow;
  final VoidCallback onAddChildPage;
  final VoidCallback onAddPageAbove;
  final ValueChanged<String> onRenamePage;
  final VoidCallback onDeletePage;
  final VoidCallback onChanged;

  @override
  State<BookletNavigation> createState() => _BookletNavigationState();
}

class _BookletNavigationState extends State<BookletNavigation> {
  NavigationNode? _editingNode;

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
      case _NavigationAction.rename:
        _startEditing();
      case _NavigationAction.delete:
        _editingNode = null;
        widget.onDeletePage();
    }
    widget.onChanged();
  }

  void _startEditing() {
    final selectedNode = widget.controller.selectedNode;
    if (selectedNode != null) {
      setState(() => _editingNode = selectedNode);
    }
  }

  void _finishEditing(String title) {
    widget.onRenamePage(title);
    setState(() => _editingNode = null);
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
                  tooltip: 'Navigation actions',
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
                    PopupMenuItem(
                      value: _NavigationAction.rename,
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Rename item'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: _NavigationAction.delete,
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('Delete page'),
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
                    selectedNode: widget.controller.selectedNode,
                    onSelected: widget.onPageSelected,
                    editingNode: _editingNode,
                    onStartEditing: _startEditing,
                    onRename: _finishEditing,
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

class _NavigationBranch extends StatefulWidget {
  const _NavigationBranch({
    required this.node,
    required this.depth,
    required this.selectedPageId,
    required this.selectedNode,
    required this.onSelected,
    required this.editingNode,
    required this.onStartEditing,
    required this.onRename,
    required this.onChanged,
  });

  final NavigationNode node;
  final int depth;
  final String? selectedPageId;
  final NavigationNode? selectedNode;
  final ValueChanged<NavigationNode> onSelected;
  final NavigationNode? editingNode;
  final VoidCallback onStartEditing;
  final ValueChanged<String> onRename;
  final VoidCallback onChanged;

  @override
  State<_NavigationBranch> createState() => _NavigationBranchState();
}

class _NavigationBranchState extends State<_NavigationBranch> {
  late final TextEditingController _titleController = TextEditingController(
    text: widget.node.title,
  );
  final FocusNode _rowFocusNode = FocusNode();
  final FocusNode _titleFocusNode = FocusNode();

  bool get _isEditing => widget.editingNode == widget.node;

  @override
  void didUpdateWidget(covariant _NavigationBranch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && oldWidget.node.title != widget.node.title) {
      _titleController.text = widget.node.title;
    }
    if (_isEditing && oldWidget.editingNode != widget.editingNode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _titleFocusNode.requestFocus();
          _titleController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _titleController.text.length,
          );
        }
      });
    }
    if (widget.selectedNode == widget.node &&
      oldWidget.selectedNode != widget.selectedNode &&
        !_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _rowFocusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _rowFocusNode.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        !_isEditing) {
      widget.onStartEditing();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _submitTitle() {
    final title = _titleController.text.trim();
    widget.onRename(title.isEmpty ? widget.node.title : title);
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final hasChildren = node.children.isNotEmpty;
    final canExpand = !node.isGroup && hasChildren;
    final isSelected = widget.selectedNode == node;

    return Padding(
      padding: EdgeInsets.only(
        top: node.isGroup ? 8 : 0,
        bottom: node.isGroup ? 10 : 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Focus(
            focusNode: _rowFocusNode,
            autofocus: isSelected,
            onKeyEvent: _handleKey,
            child: InkWell(
              onTap: () => widget.onSelected(node),
              child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              padding: EdgeInsets.only(
                left: 8.0 + widget.depth * 18,
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
                              widget.onChanged();
                            },
                          )
                        : null,
                  ),
                  Icon(node.icon, size: 18, color: Colors.grey.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _isEditing
                        ? TextField(
                            controller: _titleController,
                            focusNode: _titleFocusNode,
                            autofocus: true,
                            onSubmitted: (_) => _submitTitle(),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        : Text(
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
          ),
          if (node.isGroup || node.isExpanded)
            for (final child in node.children)
              _NavigationBranch(
                node: child,
                depth: widget.depth + 1,
                selectedPageId: widget.selectedPageId,
                selectedNode: widget.selectedNode,
                onSelected: widget.onSelected,
                editingNode: widget.editingNode,
                onStartEditing: widget.onStartEditing,
                onRename: widget.onRename,
                onChanged: widget.onChanged,
              ),
        ],
      ),
    );
  }
}

enum _NavigationAction {
  createGroup,
  addBelow,
  addChild,
  addAbove,
  rename,
  delete,
}
