import 'dart:convert';

/// Data-only history survives disposal of page widgets and controllers.
class EditorHistoryState {
  EditorHistoryState(
    List<Map<String, dynamic>> components, {
    List<String> selectedIds = const [],
    this.carets = const {},
  }) : encoded = jsonEncode(components),
       selectedIds = List.unmodifiable(selectedIds);

  final Map<String, List<int>> carets;
  final String encoded;
  final List<String> selectedIds;
  List<Map<String, dynamic>> get components =>
      (jsonDecode(encoded) as List).cast<Map<String, dynamic>>();
}

class EditorHistory {
  EditorHistory(EditorHistoryState initial, {this.limit = 100})
    : _current = initial;
  final int limit;
  EditorHistoryState _current;
  final List<EditorHistoryState> _undo = [];
  final List<EditorHistoryState> _redo = [];
  String? _mergeKey;
  DateTime? _lastEdit;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void breakGroup() {
    _mergeKey = null;
    _lastEdit = null;
  }

  bool record(EditorHistoryState next, {String? mergeKey}) {
    if (next.encoded == _current.encoded) {
      if (jsonEncode(next.carets) != jsonEncode(_current.carets)) breakGroup();
      _current = next;
      return false;
    }
    final now = DateTime.now();
    final merge =
        mergeKey != null &&
        mergeKey == _mergeKey &&
        _lastEdit != null &&
        now.difference(_lastEdit!) < const Duration(milliseconds: 650);
    if (!merge) {
      _undo.add(_current);
      if (_undo.length > limit) _undo.removeAt(0);
    }
    _current = next;
    _redo.clear();
    _mergeKey = mergeKey;
    _lastEdit = now;
    return true;
  }

  EditorHistoryState undo() {
    breakGroup();
    if (!canUndo) return _current;
    _redo.add(_current);
    return _current = _undo.removeLast();
  }

  EditorHistoryState redo() {
    breakGroup();
    if (!canRedo) return _current;
    _undo.add(_current);
    return _current = _redo.removeLast();
  }
}
