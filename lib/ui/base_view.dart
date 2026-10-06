import 'package:booklet/ui/assets/asset_manager_view.dart';
import 'package:booklet/ui/page_view/page_view.dart';
import 'package:flutter/material.dart' hide PageView;
import 'package:flutter/services.dart';

import 'dart:async';

import 'package:booklet/application/editor_controller.dart';
import 'package:booklet/ui/base_vm.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/navigation/navigation_panel_view.dart';
import 'package:booklet/ui/navigation/navigation_node.dart';
import 'package:booklet/ui/options_dock/opitons_dock.dart';

class BaseView extends StatefulWidget {
  const BaseView({
    super.key,
    required this.controller,
    required this.onShowDocumentSettings,
    required this.onShowPageSettings,
  });

  final EditorController controller;
  final VoidCallback onShowDocumentSettings;
  final VoidCallback onShowPageSettings;

  @override
  State<BaseView> createState() => BaseViewState();
}

class BaseViewState extends State<BaseView> {
  final ScrollController _scrollController = ScrollController();
  final _optionsDockKey = GlobalKey<OptionsDockState>();
  final FocusNode _pageFocusNode = FocusNode(debugLabel: 'page-shortcuts');
  double _navigationWidth = NavigationPanelView.defaultWidth;
  bool _isNavigationVisible = true;

  BaseVM get _viewModel => widget.controller.viewModel;

  @override
  void initState() {
    super.initState();
  }

  void selectComponent(ComponentBox component) {
    // Don't steal focus back to the page when this selection is the result
    // of the component's own text field gaining focus (entering edit mode).
    final claimPageFocus = !component.isFocused;
    setState(() => _viewModel.selectComponent(component));
    if (claimPageFocus) {
      _pageFocusNode.requestFocus();
    }
  }

  void selectComponentRange(ComponentBox component) {
    final claimPageFocus = !component.isFocused;
    setState(() => _viewModel.selectComponentRange(component));
    if (claimPageFocus) {
      _pageFocusNode.requestFocus();
    }
  }

  KeyEventResult _handlePageKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isShiftPressed) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() => _viewModel.extendSelectionWithArrowKey(true));
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() => _viewModel.extendSelectionWithArrowKey(false));
        return KeyEventResult.handled;
      }
    }
    final isCommandPressed =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    if (isCommandPressed && event.logicalKey == LogicalKeyboardKey.keyC) {
      if (_viewModel.selectedComponent == null) {
        return KeyEventResult.ignored;
      }
      copySelectedComponents();
      return KeyEventResult.handled;
    }
    if (isCommandPressed && event.logicalKey == LogicalKeyboardKey.keyV) {
      if (!widget.controller.canPasteComponents) {
        return KeyEventResult.ignored;
      }
      pasteComponents();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void copySelectedComponents() {
    unawaited(widget.controller.copySelectedComponents());
  }

  void pasteComponents() {
    unawaited(_pasteComponentsAsync());
  }

  Future<void> _pasteComponentsAsync() async {
    final pasted = await widget.controller.pasteComponents();
    if (!mounted || pasted.isEmpty) {
      return;
    }
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToComponent(pasted.last);
    });
  }

  void selectPage(NavigationNode node) {
    widget.controller.selectNode(node);
  }

  void clearSelectionAndFocus() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_viewModel.selectedComponent != null) {
      setState(_viewModel.clearSelectedComponent);
    }
  }

  BaseVM get viewModel => _viewModel;

  Future<bool> saveBooklet() => widget.controller.saveBooklet();

  Future<bool> saveBookletAs() => widget.controller.saveBookletAs();

  bool get hasOpenedBooklet => widget.controller.hasOpenedBooklet;

  Future<bool> openBooklet() => widget.controller.openBooklet();

  void dismissOptionsMenu() {
    _optionsDockKey.currentState?.dismissMenu();
  }

  void _toggleNavigation() {
    setState(() => _isNavigationVisible = !_isNavigationVisible);
  }

  void _resizeNavigation(double delta) {
    setState(() {
      _navigationWidth = (_navigationWidth + delta)
          .clamp(NavigationPanelView.minWidth, NavigationPanelView.maxWidth)
          .toDouble();
    });
  }

  void _createEntryBelow(int index, TextSelection? selection) {
    late final ComponentBox newComponent;
    setState(() {
      newComponent = _viewModel.createComponentBelow(
        index,
        selection: selection,
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToComponent(newComponent);
      newComponent.requestFocus();
    });
  }

  void _mergeTextComponentWithPrevious(int index) {
    ComponentBox? previousComponent;
    setState(() {
      previousComponent = _viewModel.mergeTextComponentWithPrevious(index);
    });
    if (previousComponent == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToComponent(previousComponent!);
      if (previousComponent!.isTextComponent) {
        previousComponent!.requestFocus();
      }
    });
  }

  void addComponentBelowSelected(String type) {
    final selectedComponent = _viewModel.selectedComponent;
    if (selectedComponent == null) {
      return;
    }
    final selectedIndex = _viewModel.components.indexOf(selectedComponent);
    late final ComponentBox newComponent;
    setState(() {
      newComponent = _viewModel.createComponentBelowType(selectedIndex, type);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToComponent(newComponent);
      newComponent.requestFocus();
    });
  }

  /*

May this day of your birth be auspicious!

*/

  void deleteSelectedComponent() {
    setState(_viewModel.deleteSelectedComponent);
  }

  void transformSelectedComponent(String type) {
    setState(() => _viewModel.transformSelectedComponent(type));
  }

  void _scrollToComponent(ComponentBox component) {
    final componentContext = component.componentKey.currentContext;
    if (componentContext == null) {
      return;
    }

    Scrollable.ensureVisible(
      componentContext,
      alignment: 0.5,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pageFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.controller,
        widget.controller.editorTheme,
        widget.controller.documentSettingsController,
      ]),
      builder: (context, _) => Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isNavigationVisible) ...[
                NavigationPanelView(
                  controller: _viewModel.navigation,
                  width: _navigationWidth,
                  onPageSelected: selectPage,
                  onCreateGroup: () => setState(_viewModel.addGroup),
                  onAddPageBelow: () =>
                      setState(_viewModel.addPageBelowSelected),
                  onAddChildPage: () =>
                      setState(_viewModel.addChildPageSelected),
                  onAddAssetsFolder: () =>
                      setState(widget.controller.addAssetsFolder),
                  onRenameNode: (title) =>
                      setState(() => _viewModel.renameSelectedNode(title)),
                  onDeleteNode: () =>
                      setState(widget.controller.deleteSelectedNode),
                  onDuplicateNode: () => unawaited(
                    widget.controller.duplicateSelectedNavigationNode(),
                  ),
                  onCopyNode: () =>
                      unawaited(widget.controller.copySelectedNavigationNode()),
                  onPasteNode: () => unawaited(
                    widget.controller.pasteSelectedNavigationNode(),
                  ),
                  canPasteNode: widget.controller.canPasteComponents,
                  onShowDocumentSettings: widget.onShowDocumentSettings,
                  canMoveNode: (source, target, {required into}) => _viewModel
                      .navigation
                      .canMoveNode(source, target, into: into),
                  onMoveNode: (source, target, before, into) {
                    final moved = _viewModel.navigation.moveNode(
                      source,
                      target,
                      before: before,
                      into: into,
                    );
                    if (moved) widget.controller.markDocumentChanged();
                    setState(() {});
                  },
                  onChanged: () => setState(() {}),
                ),
                _NavigationResizeHandle(onDragUpdate: _resizeNavigation),
              ],
              Expanded(
                child:
                    _viewModel.navigation.selectedNode?.isAssetsFolder == true
                    ? AssetManagerView(
                        controller: widget.controller.assetManagerController,
                      )
                    : GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: clearSelectionAndFocus,
                        child: Focus(
                          focusNode: _pageFocusNode,
                          onKeyEvent: _handlePageKeyEvent,
                          child: ColoredBox(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            // color: const Color.fromARGB(255, 224, 223, 223),
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(90),
                              child: Container(
                                  decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withValues(alpha: 0.1),
                                      blurRadius: 30,
                                      offset: Offset(0, -2),  
                                    ),
                                  ]
                                ),
                                child: PageView(
                                  editorTheme: widget.controller.editorTheme,
                                  page: widget.controller.selectedPage,
                                  onSelectComponent: selectComponent,
                                  onSelectComponentRange: selectComponentRange,
                                  onCreateEntryBelow: _createEntryBelow,
                                  onBackspaceAtStart:
                                      _mergeTextComponentWithPrevious,
                                  onTapEmptySpace: clearSelectionAndFocus,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
          Positioned(
            top: 12,
            left: _isNavigationVisible ? _navigationWidth + 20 : 12,
            child: _NavigationToggleButton(
              isNavigationVisible: _isNavigationVisible,
              onPressed: _toggleNavigation,
            ),
          ),
          if (_viewModel.navigation.selectedNode?.isAssetsFolder != true)
            Positioned.fill(
              child: OptionsDock(
                key: _optionsDockKey,
                onComponentSelected: addComponentBelowSelected,
                onComponentTransformed: transformSelectedComponent,
                onComponentDeleted: deleteSelectedComponent,
                onComponentsCopied: copySelectedComponents,
                onComponentsPasted: pasteComponents,
                onListStyleChanged: (style) =>
                  _viewModel.setSelectedListStyle(style),
                onPageSettings: widget.onShowPageSettings,
                hasSelection: _viewModel.selectedComponent != null,
                canTransformSelection: _viewModel.canTransformSelectedComponent,
                selectedListKind: _viewModel.selectedListKind,
                selectedListStyle: _viewModel.selectedListStyle,
                selectedListStyleOptions:
                  _viewModel.selectedListStyleOptions,
                canPaste: widget.controller.canPasteComponents,
                isReadOnly:
                    widget.controller.documentSettingsController.isReadOnly,
              ),
            ),
        ],
      ),
    );
  }
}

class _NavigationResizeHandle extends StatelessWidget {
  const _NavigationResizeHandle({required this.onDragUpdate});

  final ValueChanged<double> onDragUpdate;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) =>
            onDragUpdate(details.primaryDelta ?? 0),
        child: const SizedBox(width: 8),
      ),
    );
  }
}

class _NavigationToggleButton extends StatelessWidget {
  const _NavigationToggleButton({
    required this.isNavigationVisible,
    required this.onPressed,
  });

  final bool isNavigationVisible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isNavigationVisible ? 'Hide navigation' : 'Show navigation',
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        child: IconButton(
          tooltip: isNavigationVisible ? 'Hide navigation' : 'Show navigation',
          onPressed: onPressed,
          icon: Icon(
            isNavigationVisible ? Icons.chevron_left : Icons.chevron_right,
          ),
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
