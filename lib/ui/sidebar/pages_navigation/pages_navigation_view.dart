import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pages_navigation_vm.dart';
import 'navigation_menu.dart';
import 'navigation_node.dart';

typedef NavigationNodeMoveCallback = void Function(
  NavigationNode source,
  NavigationNode target,
  bool before,
  bool into,
);

enum _NavigationDropZone { before, after, into }

class PagesNavigationView extends StatefulWidget {
  const PagesNavigationView({
    super.key,
    required this.controller,
    required this.width,
    required this.onPageSelected,
    required this.onCreateGroup,
    required this.onAddPageBelow,
    required this.onAddChildPage,
    required this.onAddAssetsFolderInside,
    required this.onAddAssetsFolderBelow,
    required this.onRenameNode,
    required this.onDeleteNode,
    required this.onDuplicateNode,
    required this.onCopyNode,
    required this.onPasteNode,
    required this.canPasteNode,
    required this.canMoveNode,
    required this.onMoveNode,
    required this.onChanged,
  });

  static const double minWidth = 200;
  static const double maxWidth = 420;
  static const double defaultWidth = 272;

  final PagesNavigationVM controller;
  final double width;
  final ValueChanged<NavigationNode> onPageSelected;
  final VoidCallback onCreateGroup;
  final VoidCallback onAddPageBelow;
  final VoidCallback onAddChildPage;
  final VoidCallback onAddAssetsFolderBelow;
  final VoidCallback onAddAssetsFolderInside;
  final ValueChanged<String> onRenameNode;
  final VoidCallback onDeleteNode;
  final VoidCallback onDuplicateNode;
  final VoidCallback onCopyNode;
  final VoidCallback onPasteNode;
  final bool canPasteNode;
  final bool Function(
    NavigationNode source,
    NavigationNode target, {
    required bool into,
  })
  canMoveNode;
  final NavigationNodeMoveCallback onMoveNode;
  final VoidCallback onChanged;

  @override
  State<PagesNavigationView> createState() => _PagesNavigationViewState();
}

class _PagesNavigationViewState extends State<PagesNavigationView> {
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
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
            child: Row(
              mainAxisAlignment: .end,
              children: [
                NavigationAddMenu(
                  onCreateGroup: widget.onCreateGroup,
                  onAddPageBelow: widget.onAddPageBelow,
                  onAddChildPage: widget.onAddChildPage,
                  onAddAssetsFolderBelow: widget.onAddAssetsFolderBelow,
                  onAddAssetsFolderInside: widget.onAddAssetsFolderInside,
                  canAddChildPage:
                      widget.controller.selectedNode?.isAssetsFolder != true,
                  onChanged: widget.onChanged,
                ),
                NavigationMoreMenu(
                  hasSelection: widget.controller.selectedNode != null,
                  canPaste: widget.canPasteNode,
                  onDuplicate: widget.onDuplicateNode,
                  onCopy: widget.onCopyNode,
                  onPaste: widget.onPasteNode,
                  onRename: _startEditing,
                  onDelete: () {
                    _editingNode = null;
                    widget.onDeleteNode();
                  },
                  onChanged: widget.onChanged,
                ),
                // const SizedBox(width: 4),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 5),
              children: [
                for (final group in widget.controller.groups)
                  _NavigationBranch(
                    key: ValueKey<NavigationNode>(group),
                    node: group,
                    depth: 0,
                    selectedPageId: widget.controller.selectedPageId,
                    selectedNode: widget.controller.selectedNode,
                    onSelected: widget.onPageSelected,
                    editingNode: _editingNode,
                    onStartEditing: _startEditing,
                    onRename: _finishEditing,
                    canMoveNode: widget.canMoveNode,
                    onMoveNode: widget.onMoveNode,
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
    super.key,
    required this.node,
    required this.depth,
    required this.selectedPageId,
    required this.selectedNode,
    required this.onSelected,
    required this.editingNode,
    required this.onStartEditing,
    required this.onRename,
    required this.canMoveNode,
    required this.onMoveNode,
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
  final bool Function(
    NavigationNode source,
    NavigationNode target, {
    required bool into,
  })
  canMoveNode;
  final NavigationNodeMoveCallback onMoveNode;
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
  final GlobalKey _rowKey = GlobalKey();
  _NavigationDropZone? _activeDropZone;
  bool _isDragging = false;

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

  double _dropPosition(DragTargetDetails<NavigationNode> details) {
    final box = _rowKey.currentContext!.findRenderObject()! as RenderBox;
    final localY = box.globalToLocal(details.offset).dy;
    return (localY / box.size.height).clamp(0.0, 1.0);
  }

  _NavigationDropZone? _dropZoneFor(DragTargetDetails<NavigationNode> details) {
    final position = _dropPosition(details);
    if (widget.node.isGroup && details.data.isGroup) {
      return position < 0.5
          ? _NavigationDropZone.before
          : _NavigationDropZone.after;
    }
    if (widget.node.isGroup && details.data.isPage) {
      if (position < 0.25) return _NavigationDropZone.before;
      if (position > 0.75) return _NavigationDropZone.after;
      return _NavigationDropZone.into;
    }
    if (widget.node.isPage && details.data.isPage) {
      if (position < 0.3) return _NavigationDropZone.before;
      if (position > 0.7) return _NavigationDropZone.after;
      return _NavigationDropZone.into;
    }
    return null;
  }

  bool _isDropInto(NavigationNode source, _NavigationDropZone zone) =>
      zone == _NavigationDropZone.into;

  bool _canAcceptDrop(DragTargetDetails<NavigationNode> details) {
    final zone = _dropZoneFor(details);
    return zone != null &&
        widget.canMoveNode(
          details.data,
          widget.node,
          into: _isDropInto(details.data, zone),
        );
  }

  void _updateDropZone(DragTargetDetails<NavigationNode> details) {
    final zone = _dropZoneFor(details);
    if (zone != _activeDropZone) {
      setState(() => _activeDropZone = zone);
    }
  }

  void _acceptDrop(DragTargetDetails<NavigationNode> details) {
    final zone = _dropZoneFor(details);
    if (zone == null) return;
    widget.onMoveNode(
      details.data,
      widget.node,
      zone == _NavigationDropZone.before,
      _isDropInto(details.data, zone),
    );
    setState(() => _activeDropZone = null);
  }

  void _setDragging(bool dragging) {
    if (mounted && _isDragging != dragging) {
      setState(() => _isDragging = dragging);
    }
  }

  Widget _draggableFor(BuildContext context, Widget child) {
    final platform = Theme.of(context).platform;
    final isDesktop =
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux;
    final node = widget.node;
    if (isDesktop) {
      return Draggable<NavigationNode>(
        data: node,
        maxSimultaneousDrags: node.isGroup || node.isPage ? 1 : 0,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        onDragStarted: () => _setDragging(true),
        onDragEnd: (_) => _setDragging(false),
        feedback: const SizedBox.shrink(),
        child: child,
      );
    }
    return LongPressDraggable<NavigationNode>(
      data: node,
      delay: const Duration(milliseconds: 250),
      maxSimultaneousDrags: node.isGroup || node.isPage ? 1 : 0,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragStarted: () => _setDragging(true),
      onDragEnd: (_) => _setDragging(false),
      feedback: const SizedBox.shrink(),
      child: child,
    );
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
            child: DragTarget<NavigationNode>(
              onWillAcceptWithDetails: _canAcceptDrop,
              onMove: _updateDropZone,
              onLeave: (_) => setState(() => _activeDropZone = null),
              onAcceptWithDetails: _acceptDrop,
              builder: (context, candidates, _) => _draggableFor(
                context,
                InkWell(
                  onTap: () => widget.onSelected(node),
                  child: Container(
                    key: _rowKey,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 1,
                    ),
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
                      border:
                          _isDragging ||
                              (candidates.isNotEmpty &&
                                  _activeDropZone == _NavigationDropZone.into)
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: _isDragging ? 1.5 : 2,
                            )
                          : null,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: node.isGroup ? 0 : 20,
                              child: canExpand
                                  ? IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      splashRadius: 16,
                                      tooltip: node.isExpanded
                                          ? 'Collapse'
                                          : 'Expand',
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

                            SizedBox(
                              width: node.isGroup ? 0 : 15,
                              child: node.isGroup
                                  ? null
                                  : Icon(
                                      node.icon,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
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
                                            : node.isAssetsFolder
                                            ? FontWeight.w400
                                            : FontWeight.w500,
                                        color: // node.isAssetsFolder ? Colors.grey :
                                        Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                        // fontStyle: node.isAssetsFolder ? . : .normal
                                      ),
                                    ),
                            ),
                          ],
                        ),
                        if (candidates.isNotEmpty &&
                            _activeDropZone == _NavigationDropZone.before)
                          Positioned(
                            top: -2,
                            left: 0,
                            right: 0,
                            child: _dropIndicator(context),
                          ),
                        if (candidates.isNotEmpty &&
                            _activeDropZone == _NavigationDropZone.after)
                          Positioned(
                            bottom: -2,
                            left: 0,
                            right: 0,
                            child: _dropIndicator(context),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (node.isGroup || node.isExpanded)
            for (final child in node.children)
              _NavigationBranch(
                key: ValueKey<NavigationNode>(child),
                node: child,
                depth: widget.depth + 1,
                selectedPageId: widget.selectedPageId,
                selectedNode: widget.selectedNode,
                onSelected: widget.onSelected,
                editingNode: widget.editingNode,
                onStartEditing: widget.onStartEditing,
                onRename: widget.onRename,
                canMoveNode: widget.canMoveNode,
                onMoveNode: widget.onMoveNode,
                onChanged: widget.onChanged,
              ),
        ],
      ),
    );
  }

  Widget _dropIndicator(BuildContext context) => Container(
    height: 3,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary,
      borderRadius: BorderRadius.circular(2),
    ),
  );
}
