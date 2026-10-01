import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'navigation_panel_vm.dart';
import 'navigation_menu.dart';
import 'navigation_node.dart';

class NavigationPanelView extends StatefulWidget {
  const NavigationPanelView({
    super.key,
    required this.controller,
    required this.width,
    required this.onPageSelected,
    required this.onCreateGroup,
    required this.onAddPageBelow,
    required this.onAddChildPage,
    required this.onAddAssetsFolder,
    required this.onRenameNode,
    required this.onDeleteNode,
    required this.onChanged,
  });

  static const double minWidth = 200;
  static const double maxWidth = 420;
  static const double defaultWidth = 272;

  final NavigationPanelVM controller;
  final double width;
  final ValueChanged<NavigationNode> onPageSelected;
  final VoidCallback onCreateGroup;
  final VoidCallback onAddPageBelow;
  final VoidCallback onAddChildPage;
  final VoidCallback onAddAssetsFolder;
  final ValueChanged<String> onRenameNode;
  final VoidCallback onDeleteNode;
  final VoidCallback onChanged;

  @override
  State<NavigationPanelView> createState() => _NavigationPanelViewState();
}

class _NavigationPanelViewState extends State<NavigationPanelView> {
  NavigationNode? _editingNode;

  void _startEditing() {
    final selectedNode = widget.controller.selectedNode;
    if (selectedNode != null) {
      setState(() => _editingNode = selectedNode);
    }
  }

  void _finishEditing(String title) {
    widget.onRenameNode(title);
    setState(() => _editingNode = null);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
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
                NavigationAddMenu(
                  onCreateGroup: widget.onCreateGroup,
                  onAddPageBelow: widget.onAddPageBelow,
                  onAddChildPage: widget.onAddChildPage,
                  onAddAssetsFolder: widget.onAddAssetsFolder,
                  canAddChildPage:
                      widget.controller.selectedNode?.isAssetsFolder != true,
                  onChanged: widget.onChanged,
                ),
                NavigationMoreMenu(
                  hasSelection: widget.controller.selectedNode != null,
                  onRename: _startEditing,
                  onDelete: () {
                    _editingNode = null;
                    widget.onDeleteNode();
                  },
                  onChanged: widget.onChanged,
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
                  color: isSelected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
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
                    Icon(
                      node.icon,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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
                                color: Theme.of(context).colorScheme.onSurface,
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
