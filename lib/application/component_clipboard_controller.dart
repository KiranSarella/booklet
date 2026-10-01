import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:booklet/ui/components/component_snapshot.dart';

/// Puts copied component content on the OS clipboard (as a tagged JSON
/// payload) instead of holding it in memory, so copy/paste works across
/// pages, documents, and separate app windows (each of which runs its own
/// isolate and cannot share Dart objects by reference).
class ComponentClipboardController {
  static const _marker = 'booklet-components-v1';

  Future<void> copy(List<ComponentSnapshot> snapshots) async {
    final payload = jsonEncode({
      'marker': _marker,
      'components': [for (final snapshot in snapshots) snapshot.toJson()],
    });
    await Clipboard.setData(ClipboardData(text: payload));
  }

  Future<List<ComponentSnapshot>> paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map || decoded['marker'] != _marker) {
        return const [];
      }
      final components = decoded['components'];
      if (components is! List) {
        return const [];
      }
      return [
        for (final component in components.whereType<Map>())
          ComponentSnapshot.fromJson(Map<String, dynamic>.from(component)),
      ];
    } on FormatException {
      // Clipboard holds unrelated text (not our JSON payload); nothing to paste.
      return const [];
    }
  }
}

