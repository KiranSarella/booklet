import 'package:booklet/ui/components/component_snapshot.dart';

/// Holds copied component content in memory so it can be pasted into the
/// same page, another page, or another booklet document opened later in the
/// same session.
class ComponentClipboardController {
  List<ComponentSnapshot> _snapshots = const [];

  bool get hasContent => _snapshots.isNotEmpty;

  List<ComponentSnapshot> get snapshots => _snapshots;

  void copy(List<ComponentSnapshot> snapshots) {
    _snapshots = List.unmodifiable(snapshots);
  }
}
