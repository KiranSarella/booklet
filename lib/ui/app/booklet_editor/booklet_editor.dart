import 'package:flutter/material.dart';
import 'package:booklet/ui/app/booklet_editor/booklet_editor_vm.dart';
import 'package:booklet/ui/app/components/components.dart';
import 'package:booklet/ui/app/editor_themes/editor_themes.dart';
import 'package:booklet/ui/app/navigation/navigation.dart';
import 'package:booklet/ui/app/navigation/navigation_models.dart';

class BookletEditor extends StatefulWidget {
  const BookletEditor({
    super.key,
    required this.editorTheme,
    required this.onSelectionChanged,
  });

  final EditorTheme editorTheme;
  final ValueChanged<bool> onSelectionChanged;

  @override
  State<BookletEditor> createState() => BookletEditorState();
}

class BookletEditorState extends State<BookletEditor> {
  final ScrollController _scrollController = ScrollController();
  late final BookletEditorViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = BookletEditorViewModel(widget.editorTheme);
  }

  void selectComponent(ComponentBox component) {
    setState(() => _viewModel.selectComponent(component));
    widget.onSelectionChanged(true);
  }

  void selectPage(NavigationNode node) {
    final pageId = node.pageId;
    if (pageId == null) {
      return;
    }
    setState(() => _viewModel.selectPage(pageId));
    widget.onSelectionChanged(false);
  }

  BookletEditorViewModel get viewModel => _viewModel;

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
    widget.onSelectionChanged(false);
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
      builder: (context, _) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BookletNavigation(
            controller: _viewModel.navigation,
            onPageSelected: selectPage,
            onCreateGroup: () => setState(_viewModel.addGroup),
            onAddPageBelow: () => setState(_viewModel.addPageBelowSelected),
            onAddChildPage: () => setState(_viewModel.addChildPageSelected),
            onAddPageAbove: () => setState(_viewModel.addPageAboveSelected),
            onChanged: () => setState(() {}),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: _viewModel.components.length,
              itemBuilder: (context, index) {
                final component = _viewModel.components[index];
                final isSelected = _viewModel.selectedComponent == component;

                return Padding(
                  key: component.componentKey,
                  padding: const EdgeInsets.only(bottom: 6),
                  child: component.createUI(
                    isSelected: isSelected,
                    onSelect: () => selectComponent(component),
                    onCreateBelow: () => _createEntryBelow(index),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// class _BookletEditorState extends State<BookletEditor> {
//   final ScrollController _scrollController = ScrollController();
//   final BookletEditorViewModel _viewModel = BookletEditorViewModel();

//   void _selectIndex(int index) {
//     debugPrint('selected index: $index');
//     setState(() => _viewModel.selectComponent(index));
//   }

//   void _createEntryBelow(int index) {
//     late final BookletComponent newComponent;

//     setState(() {
//       newComponent = _viewModel.createComponentBelow(index);
//     });

//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (_scrollController.hasClients) {
//         _scrollController.animateTo(
//           _scrollController.position.maxScrollExtent,
//           duration: const Duration(milliseconds: 180),
//           curve: Curves.easeOut,
//         );
//       }

//       FocusScope.of(context).requestFocus(newComponent.focusNode);
//     });
//   }

//   @override
//   void dispose() {
//     _scrollController.dispose();
//     _viewModel.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return ListView.builder(
//       controller: _scrollController,
//       padding: const EdgeInsets.all(20),
//       itemCount: _viewModel.components.length,
//       itemBuilder: (context, index) {
//         final component = _viewModel.components[index];
//         final isSelected = _viewModel.selectedComponent == component;

//         return Padding(
//           padding: const EdgeInsets.only(bottom: 12),
//           child: AutoHeightRichText2(
//             component: component,
//             isSelected: isSelected,
//             onSelect: () => _selectIndex(index),
//             onCreateBelow: () => _createEntryBelow(index),
//             textStyle: TextStyle(
//               fontSize: 18,
//               fontWeight: .w600,
//               color: const Color.fromARGB(255, 10, 84, 13),
//             ),
//           ),
//         );
//       },
//     );
//   }
// }
