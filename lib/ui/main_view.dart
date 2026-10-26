import 'dart:async';

import 'package:booklet/ui/document_status_bar.dart';
import 'package:flutter/material.dart';

import 'package:booklet/application/editor_controller.dart';
import 'package:booklet/ui/detail/base_detail_view.dart';
import 'package:booklet/ui/detail/editor/editor_view.dart';
import 'package:booklet/ui/detail/editor/editor_vm.dart';
import 'package:booklet/ui/sidebar/base_sidebar_view.dart';
import 'package:booklet/ui/sidebar/document_settings/document_settings_vm.dart';
import 'package:booklet/ui/sidebar/pages_navigation/pages_navigation_view.dart';

class MainView extends StatefulWidget {
  const MainView({
    super.key,
    required this.controller,
    required this.onOpenInNewWindow,
  });

  final EditorController controller;
  final VoidCallback onOpenInNewWindow;

  @override
  State<MainView> createState() => MainViewState();
}

class MainViewState extends State<MainView> {
  final _editorKey = GlobalKey<EditorViewState>();
  double _navigationWidth = PagesNavigationView.defaultWidth;
  bool _isNavigationVisible = true;

  EditorVM get _viewModel => widget.controller.viewModel;

  void dismissOptionsMenu() => _editorKey.currentState?.dismissOptionsMenu();

  void _toggleNavigation() {
    setState(() => _isNavigationVisible = !_isNavigationVisible);
  }

  void _resizeNavigation(double delta) {
    setState(() {
      _navigationWidth = (_navigationWidth + delta)
          .clamp(PagesNavigationView.minWidth, PagesNavigationView.maxWidth)
          .toDouble();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.controller,
        widget.controller.documentSettingsController,
      ]),
      builder: (context, _) => Stack(
        children: [
          Column(
            children: [
              if (widget.controller.examiningSnapshot)
                MaterialBanner(
                  content: Text(
                    'Examining snapshot from ${widget.controller.restoredSnapshotDay}. Your original booklet is safe.',
                  ),
                  leading: const Icon(Icons.history),
                  actions: [
                    TextButton(
                      onPressed: widget.controller.snapshotsBusy
                          ? null
                          : widget.controller.discardRestoredChanges,
                      child: const Text('Discard restored changes'),
                    ),
                    TextButton(
                      onPressed:
                          widget.controller.snapshotsBusy ||
                              widget
                                  .controller
                                  .documentSettingsController
                                  .isReadOnly
                          ? null
                          : widget.controller.keepRestoredChanges,
                      child: const Text('Keep this version'),
                    ),
                  ],
                ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isNavigationVisible) ...[
                      BaseSidebarView(
                        width: _navigationWidth,
                        documentSettingsViewModel: DocumentSettingsVM(
                          settingsController:
                              widget.controller.documentSettingsController,
                          editorController: widget.controller,
                        ),
                        pagesNavigation: PagesNavigationView(
                          controller: _viewModel.navigation,
                          width: _navigationWidth,
                          isReadOnly: widget
                              .controller
                              .documentSettingsController
                              .isReadOnly,
                          onPageSelected: widget.controller.selectNode,
                          onCreateGroup: () => setState(_viewModel.addGroup),
                          onAddPageBelow: () =>
                              setState(_viewModel.addPageBelowSelected),
                          onAddChildPage: () =>
                              setState(_viewModel.addChildPageSelected),
                          onAddAssetsFolderBelow: () =>
                              setState(widget.controller.addAssetsFolderBelow),
                          onAddAssetsFolderInside: () =>
                              setState(widget.controller.addAssetsFolderInside),
                          onRenameNode: (title) => setState(
                            () => _viewModel.renameSelectedNode(title),
                          ),
                          onDeleteNode: () =>
                              unawaited(widget.controller.deleteSelectedNode()),
                          onDuplicateNode: () => unawaited(
                            widget.controller.duplicateSelectedNavigationNode(),
                          ),
                          onCopyNode: () => unawaited(
                            widget.controller.copySelectedNavigationNode(),
                          ),
                          onPasteNode: () => unawaited(
                            widget.controller.pasteSelectedNavigationNode(),
                          ),
                          canPasteNode: widget.controller.canPasteComponents,
                          canMoveNode: (source, target, {required into}) =>
                              _viewModel.navigation.canMoveNode(
                                source,
                                target,
                                into: into,
                              ),
                          onMoveNode: (source, target, before, into) {
                            final moved = _viewModel.navigation.moveNode(
                              source,
                              target,
                              before: before,
                              into: into,
                            );
                            if (moved) {
                              widget.controller.markDocumentChanged();
                            }
                            setState(() {});
                          },
                          onChanged: () => setState(() {}),
                        ),
                      ),
                      _NavigationResizeHandle(onDragUpdate: _resizeNavigation),
                    ],
                    Expanded(
                      child: BaseDetailView(
                        controller: widget.controller,
                        editorKey: _editorKey,
                        isReadOnly: widget
                            .controller
                            .documentSettingsController
                            .isReadOnly,
                      ),
                    ),
                  ],
                ),
              ),
              DocumentStatusBar(
                documentPath: widget.controller.snapshotPackage,
                pageSettingsController: widget.controller.editorTheme,
                documentSettingsController:
                    widget.controller.documentSettingsController,
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
          if (widget.controller.snapshotsBusy ||
              widget.controller.trashBusy) ...[
            const Positioned.fill(
              child: ModalBarrier(dismissible: false, color: Color(0x22000000)),
            ),
            const Center(child: CircularProgressIndicator()),
          ],
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
