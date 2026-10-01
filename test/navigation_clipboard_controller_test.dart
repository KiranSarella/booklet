import 'package:booklet/application/navigation_clipboard_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NavigationClipboardController payload codec', () {
    test('round-trips navigation subtree bundles', () {
      final bundle = {
        'node': {'type': 'group', 'title': 'Research'},
        'pages': {
          'page-1': {'id': 'page-1', 'components': []},
        },
      };

      final encoded = NavigationClipboardController.encode(bundle);
      final decoded = NavigationClipboardController.decode(encoded);

      expect(decoded, bundle);
    });

    test('ignores unrelated or malformed clipboard contents', () {
      expect(NavigationClipboardController.decode('plain text'), isNull);
      expect(
        NavigationClipboardController.decode(
          '{"marker":"other-format","bundle":{}}',
        ),
        isNull,
      );
    });
  });
}
