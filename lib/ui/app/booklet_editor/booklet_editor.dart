import 'package:flutter/material.dart';
import 'package:booklet/ui/app/booklet_editor/booklet_editor_vm.dart';
import 'package:booklet/ui/app/components/components.dart';
import 'package:booklet/ui/app/editor_themes/editor_themes.dart';
import 'package:booklet/ui/app/navigation/navigation.dart';
import 'package:booklet/ui/app/navigation/navigation_models.dart';
import 'package:booklet/ui/app/options_dock/opitons_dock.dart';
import 'package:booklet/storage/booklet_file.dart';

class BookletEditor extends StatefulWidget {
  const BookletEditor({super.key, required this.editorTheme});

  final EditorTheme editorTheme;

  @override
  State<BookletEditor> createState() => BookletEditorState();
}

class BookletEditorState extends State<BookletEditor> {
  final ScrollController _scrollController = ScrollController();
  final _optionsDockKey = GlobalKey<OptionsDockState>();
  late final BookletEditorViewModel _viewModel;
  double _navigationWidth = BookletNavigation.defaultWidth;
  bool _isNavigationVisible = true;

  @override
  void initState() {
    super.initState();
    _viewModel = BookletEditorViewModel(widget.editorTheme);
  }

  void selectComponent(ComponentBox component) {
    setState(() => _viewModel.selectComponent(component));
  }

  void selectPage(NavigationNode node) {
    setState(() => _viewModel.selectNode(node));
  }

  void clearSelectionAndFocus() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_viewModel.selectedComponent != null) {
      setState(_viewModel.clearSelectedComponent);
    }
  }

  BookletEditorViewModel get viewModel => _viewModel;

  Future<bool> saveBooklet() => BookletFile.save(_viewModel);

  Future<bool> saveBookletAs() => BookletFile.saveAs(_viewModel);

  bool get hasOpenedBooklet => _viewModel.documentPath != null;

  Future<bool> openBooklet() async {
    final opened = await BookletFile.open(_viewModel);
    if (opened && mounted) {
      setState(() {});
    }
    return opened;
  }

  void dismissOptionsMenu() {
    _optionsDockKey.currentState?.dismissMenu();
  }

  void _toggleNavigation() {
    setState(() => _isNavigationVisible = !_isNavigationVisible);
  }

  void _resizeNavigation(double delta) {
    setState(() {
      _navigationWidth = (_navigationWidth + delta)
          .clamp(BookletNavigation.minWidth, BookletNavigation.maxWidth)
          .toDouble();
    });
  }

  void _createEntryBelow(int index) {
    late final ComponentBox newComponent;
    setState(() {
      newComponent = _viewModel.createComponentBelow(index);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToComponent(newComponent);
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
      _scrollToComponent(newComponent);
    });
  }

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
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.editorTheme,
      builder: (context, _) => Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isNavigationVisible) ...[
                BookletNavigation(
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
                  child: ColoredBox(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(90),
                      child: BookletPageView(
                        editorTheme: widget.editorTheme,
                        viewModel: _viewModel,
                        onSelectComponent: selectComponent,
                        onCreateEntryBelow: _createEntryBelow,
                        onTapEmptySpace: clearSelectionAndFocus,
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

class BookletPageView extends StatelessWidget {
  const BookletPageView({
    super.key,
    required this.editorTheme,
    required this.viewModel,
    required this.onSelectComponent,
    required this.onCreateEntryBelow,
    required this.onTapEmptySpace,
  });

  final EditorTheme editorTheme;
  final BookletEditorViewModel viewModel;
  final ValueChanged<ComponentBox> onSelectComponent;
  final ValueChanged<int> onCreateEntryBelow;
  final VoidCallback onTapEmptySpace;

  @override
  Widget build(BuildContext context) {
    final pageTheme = Theme.of(context).copyWith(
      brightness: editorTheme.effectiveBrightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: editorTheme.effectiveBrightness,
      ),
    );

    return Theme(
      data: pageTheme,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTapEmptySpace,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 900),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(color: editorTheme.pageBackgroundColor),
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsets.all(60),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (
                  var index = 0;
                  index < viewModel.components.length;
                  index++
                )
                  Padding(
                    key: viewModel.components[index].componentKey,
                    padding: const EdgeInsets.only(bottom: 6),
                    child: viewModel.components[index].createUI(
                      onSelect: () =>
                          onSelectComponent(viewModel.components[index]),
                      onCreateBelow: () => onCreateEntryBelow(index),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
