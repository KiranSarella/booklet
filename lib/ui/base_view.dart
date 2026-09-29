import 'package:booklet/ui/page_view/page_view.dart';
import 'package:flutter/material.dart' hide PageView;
import 'package:flutter/services.dart';
import 'package:booklet/application/editor_controller.dart';
import 'package:booklet/ui/base_vm.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/navigation/navigation_panel_view.dart';
import 'package:booklet/ui/navigation/navigation_node.dart';
import 'package:booklet/ui/options_dock/opitons_dock.dart';

class BaseView extends StatefulWidget {
  const BaseView({super.key, required this.controller});

  final EditorController controller;

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
    if (!HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() => _viewModel.extendSelectionWithArrowKey(true));
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() => _viewModel.extendSelectionWithArrowKey(false));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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

  void _createEntryBelow(int index) {
    late final ComponentBox newComponent;
    setState(() {
      newComponent = _viewModel.createComponentBelow(index);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToComponent(newComponent);
      newComponent.requestFocus();
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
                  onAddPageAbove: () =>
                      setState(_viewModel.addPageAboveSelected),
                  onRenamePage: (title) =>
                      setState(() => _viewModel.renameSelectedPage(title)),
                  onDeletePage: () => setState(_viewModel.deleteSelectedPage),
                  onChanged: () => setState(() {}),
                ),
                _NavigationResizeHandle(onDragUpdate: _resizeNavigation),
              ],
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: clearSelectionAndFocus,
                  child: Focus(
                    focusNode: _pageFocusNode,
                    onKeyEvent: _handlePageKeyEvent,
                    child: ColoredBox(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(90),
                        child: PageView(
                          editorTheme: widget.controller.editorTheme,
                          page: widget.controller.selectedPage,
                          onSelectComponent: selectComponent,
                          onSelectComponentRange: selectComponentRange,
                          onCreateEntryBelow: _createEntryBelow,
                          onTapEmptySpace: clearSelectionAndFocus,
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
          Positioned.fill(
            child: OptionsDock(
              key: _optionsDockKey,
              onComponentSelected: addComponentBelowSelected,
              onComponentTransformed: transformSelectedComponent,
              onComponentDeleted: deleteSelectedComponent,
              hasSelection: _viewModel.selectedComponent != null,
              canTransformSelection: _viewModel.canTransformSelectedComponent,
              isReadOnly: widget.controller.documentSettingsController.isReadOnly,
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
