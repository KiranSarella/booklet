import 'package:booklet/storage/rich_text_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RichTextCodec', () {
    test('converts plain text Delta to RichTextData and back', () {
      final delta = [
        {'insert': 'Hello world\n'},
      ];

      final richText = RichTextCodec.deltaToRichText(delta);
      expect(richText.content, 'Hello world');
      expect(richText.styles, isEmpty);

      final recreatedDelta = RichTextCodec.richTextToDelta(richText);
      expect(recreatedDelta, [
        {'insert': 'Hello world\n'},
      ]);
    });

    test('converts styled Delta with bold span using start and length', () {
      final delta = [
        {'insert': 'This is a '},
        {
          'insert': 'testing',
          'attributes': {'bold': true},
        },
        {'insert': ' page.'},
        {
          'insert': '\n',
          'attributes': {'align': 'left'},
        },
      ];

      final richText = RichTextCodec.deltaToRichText(delta);
      expect(richText.content, 'This is a testing page.');
      expect(richText.styles.length, 1);
      expect(richText.styles.first.start, 10);
      expect(richText.styles.first.length, 7);
      expect(richText.styles.first.attributes, {'bold': true});

      final serialized = richText.toJson();
      expect(serialized['content'], 'This is a testing page.');
      expect(serialized['styles'], [
        {
          'start': 10,
          'length': 7,
          'style': 'bold',
          'attributes': {'bold': true},
        }
      ]);

      final recreatedDelta = RichTextCodec.richTextToDelta(richText);
      expect(recreatedDelta, [
        {'insert': 'This is a '},
        {
          'insert': 'testing',
          'attributes': {'bold': true},
        },
        {'insert': ' page.\n'},
      ]);
    });

    test('handles overlapping styles correctly', () {
      final richText = RichTextData(
        content: 'ABCDEFGHIJ',
        styles: const [
          StyleSpan(
            start: 1,
            length: 4,
            attributes: {'bold': true},
          ),
          StyleSpan(
            start: 3,
            length: 5,
            attributes: {'italic': true},
          ),
        ],
      );

      final delta = RichTextCodec.richTextToDelta(richText);
      expect(delta, [
        {'insert': 'A'},
        {
          'insert': 'BC',
          'attributes': {'bold': true},
        },
        {
          'insert': 'DE',
          'attributes': {'bold': true, 'italic': true},
        },
        {
          'insert': 'FGH',
          'attributes': {'italic': true},
        },
        {'insert': 'IJ\n'},
      ]);
    });

    test('deserializes with "lenght" typo tolerance and "style" shorthand', () {
      final json = {
        'content': 'Hello world',
        'styles': [
          {
            'start': 6,
            'lenght': 5,
            'style': 'bold',
          }
        ],
      };

      final richText = RichTextData.fromJson(json);
      expect(richText.content, 'Hello world');
      expect(richText.styles.length, 1);
      expect(richText.styles.first.start, 6);
      expect(richText.styles.first.length, 5);
      expect(richText.styles.first.attributes, {'bold': true});

      final delta = RichTextCodec.richTextToDelta(richText);
      expect(delta, [
        {'insert': 'Hello '},
        {
          'insert': 'world',
          'attributes': {'bold': true},
        },
        {'insert': '\n'},
      ]);
    });

    test('handles empty content', () {
      const richText = RichTextData(content: '', styles: []);
      final delta = RichTextCodec.richTextToDelta(richText);
      expect(delta, [
        {'insert': '\n'},
      ]);
    });
  });
}

