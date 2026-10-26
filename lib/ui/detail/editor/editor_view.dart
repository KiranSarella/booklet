import 'dart:async';

import 'package:flutter/material.dart' hide PageView;
import 'package:flutter/services.dart';

import 'package:booklet/application/editor_controller.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/detail/editor/editor_vm.dart';
import 'package:booklet/ui/detail/editor/options_dock/opitons_dock.dart';
import 'package:booklet/ui/detail/editor/page_settings/page_settings_view.dart';
import 'package:booklet/ui/detail/editor/page_settings/page_settings_vm.dart';
import 'package:booklet/ui/detail/editor/page_view/page_view.dart';

class EditorView extends StatefulWidget {
  const EditorView({super.key, required this.controller});

  final EditorController controller;

  @override
  State<EditorView> createState() => EditorViewState();
}

class EditorViewState extends State<EditorView> {
  final ScrollController _scrollController = ScrollController();
  final _optionsDockKey = GlobalKey<OptionsDockState>();
  final FocusNode _pageFocusNode = FocusNode(debugLabel: 'page-shortcuts');

  EditorVM get _viewModel => widget.controller.viewModel;

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
      final selected = _viewModel.selectedComponent;
      if (selected == null || selected.isFocused) {
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
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final selected = _viewModel.selectedComponent;
      if (selected != null && !selected.isFocused) {
        setState(
          () => _viewModel.moveSelectedComponent(
            event.logicalKey == LogicalKeyboardKey.arrowDown,
          ),
        );
        return KeyEventResult.handled;
      }
    }
    final isCommandPressed =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    if (isCommandPressed && event.logicalKey == LogicalKeyboardKey.keyC) {
      final selectedComponent = _viewModel.selectedComponent;
      if (selectedComponent == null || selectedComponent.isFocused) {
        return KeyEventResult.ignored;
      }
      copySelectedComponents();
      return KeyEventResult.handled;
    }
    if (isCommandPressed && event.logicalKey == LogicalKeyboardKey.keyV) {
      if (_viewModel.selectedComponent?.isFocused ?? false) {
        return KeyEventResult.ignored;
      }
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

  void clearSelectionAndFocus() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_viewModel.selectedComponent != null) {
      setState(_viewModel.clearSelectedComponent);
    }
  }

  EditorVM get viewModel => _viewModel;

  void dismissOptionsMenu() {
    _optionsDockKey.currentState?.dismissMenu();
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

  void _moveToTextComponent(int index, bool moveDown) {
    final components = _viewModel.components;
    var targetIndex = index + (moveDown ? 1 : -1);
    while (targetIndex >= 0 && targetIndex < components.length) {
      final target = components[targetIndex];
      if (target.component.state is TextComponentState) {
        setState(() => _viewModel.selectComponent(target));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) target.requestFocus();
        });
        return;
      }
      targetIndex += moveDown ? 1 : -1;
    }
  }

  Future<bool> _pasteTextAt(int index, String text) async {
    ComponentBox? last;
    setState(() {
      last = _viewModel.pasteTextLines(index, text);
    });
    final target = last;
    if (target == null) return false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToComponent(target);
      target.requestFocus();
    });
    return true;
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
    final selectedIndex = selectedComponent == null
        ? -1
        : _viewModel.components.indexOf(selectedComponent);
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
  void initState() {
    super.initState();
    FocusManager.instance.addEarlyKeyEventHandler(_handleHistoryKey);
  }

  void _applyHistory({bool redo = false}) {
    redo ? _viewModel.redo() : _viewModel.undo();
    _pageFocusNode.requestFocus();
  }

  KeyEventResult _handleHistoryKey(KeyEvent event) {
    if (event is! KeyDownEvent || !_pageFocusNode.hasFocus) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    if (!keyboard.isMetaPressed && !keyboard.isControlPressed) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyZ) {
      _applyHistory(redo: keyboard.isShiftPressed);
      return KeyEventResult.handled;
    }
    if (keyboard.isControlPressed &&
        event.logicalKey == LogicalKeyboardKey.keyY) {
      _applyHistory(redo: true);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_handleHistoryKey);
    _scrollController.dispose();
    _pageFocusNode.dispose();
    super.dispose();
  }

  void _showPageSettings() {
    showDialog<void>(
      context: context,
      builder: (context) => PageSettingsDialog(
        viewModel: PageSettingsVM(
          pageSettingsController: widget.controller.editorTheme,
          documentSettingsController:
              widget.controller.documentSettingsController,
        ),
      ),
    );
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
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: clearSelectionAndFocus,
            child: Focus(
              focusNode: _pageFocusNode,
              onKeyEvent: _handlePageKeyEvent,
              child: ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: SizedBox.expand(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(90),
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.1),
                            blurRadius: 30,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: PageView(
                        editorTheme: widget.controller.editorTheme,
                        page: widget.controller.selectedPage,
                        onSelectComponent: selectComponent,
                        onSelectComponentRange: selectComponentRange,
                        onCreateEntryBelow: _createEntryBelow,
                        onBackspaceAtStart: _mergeTextComponentWithPrevious,
                        onMoveToAdjacentTextComponent: _moveToTextComponent,
                        onPasteText: _pasteTextAt,
                        onTapEmptySpace: clearSelectionAndFocus,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 86,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Undo',
                  icon: const Icon(Icons.undo),
                  onPressed: _viewModel.canUndo ? () => _applyHistory() : null,
                ),
                IconButton(
                  tooltip: 'Redo',
                  icon: const Icon(Icons.redo),
                  onPressed: _viewModel.canRedo
                      ? () => _applyHistory(redo: true)
                      : null,
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: OptionsDock(
              key: _optionsDockKey,
              onComponentSelected: addComponentBelowSelected,
              onComponentTransformed: transformSelectedComponent,
              onFocusBarToggled: () =>
                  setState(_viewModel.toggleFocusBarOnSelection),
              onComponentDeleted: deleteSelectedComponent,
              onComponentsCopied: copySelectedComponents,
              onComponentsPasted: pasteComponents,
              onListStyleChanged: (style) =>
                  _viewModel.setSelectedListStyle(style),
              onPageSettings: _showPageSettings,
              hasSelection: _viewModel.selectedComponent != null,
              hasFocusBar: _viewModel.selectedHasFocusBar,
              canTransformSelection: _viewModel.canTransformSelectedComponent,
              selectedListKind: _viewModel.selectedListKind,
              selectedListStyle: _viewModel.selectedListStyle,
              selectedListStyleOptions: _viewModel.selectedListStyleOptions,
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
