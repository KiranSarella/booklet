import 'package:flutter/material.dart';
import 'package:booklet/ui/helpers_ui/autoheight_richtext.dart';



class BookletEditor extends StatefulWidget {
  const BookletEditor({super.key});

  @override
  State<BookletEditor> createState() => _BookletEditorState();
}

class _BookletEditorState extends State<BookletEditor> {
  final ScrollController _scrollController = ScrollController();
  final List<RichTextEntry> _entries = [RichTextEntry()];
  int _selectedIndex = 0;

  void _selectIndex(int index) {
    debugPrint('selected index: $index');
    setState(() => _selectedIndex = index);
  }

  void _createEntryBelow(int index) {
    final newEntry = RichTextEntry();

    setState(() {
      _entries.insert(index + 1, newEntry);
      _selectedIndex = index + 1;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }

      FocusScope.of(context).requestFocus(newEntry.focusNode);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final entry in _entries) {
      entry.controller.dispose();
      entry.focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        final isSelected = _selectedIndex == index;
    
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AutoHeightRichText(
            entry: entry,
            isSelected: isSelected,
            onSelect: () => _selectIndex(index),
            onCreateBelow: () => _createEntryBelow(index),
          ),
        );
      },
    );
  }
}
