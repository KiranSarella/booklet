import 'dart:convert';

import 'package:flutter/services.dart';

class NavigationClipboardController {
  static const _marker = 'booklet-navigation-v1';

  Future<void> copy(Map<String, dynamic> bundle) async {
    await Clipboard.setData(ClipboardData(text: encode(bundle)));
  }

  Future<Map<String, dynamic>?> paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) {
      return null;
    }
    return decode(text);
  }

  static String encode(Map<String, dynamic> bundle) =>
      jsonEncode({'marker': _marker, 'bundle': bundle});

  static Map<String, dynamic>? decode(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map || decoded['marker'] != _marker) {
        return null;
      }
      final bundle = decoded['bundle'];
      return bundle is Map ? Map<String, dynamic>.from(bundle) : null;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}
