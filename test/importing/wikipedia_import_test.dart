import 'package:booklet/importing/html_importer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'keeps Wikipedia article headings, links and images without page chrome',
    () {
      final result = HtmlImporter.parse(
        '''
    <title>Article - Wikipedia</title><main>
    <h1 id="firstHeading">Article</h1><div>Site tools</div>
    <div class="mw-parser-output"><div class="ambox">Notice</div>
    <p>About <a href="/wiki/Science">science</a>.</p>
    <div class="mw-heading"><h2>History</h2><span class="mw-editsection">edit</span></div>
    <figure><img src="//upload.wikimedia.org/pic.png"><figcaption>Caption</figcaption></figure>
    <div class="navbox">Navigation links</div></div></main>''',
        baseUri: Uri.parse('https://en.wikipedia.org/wiki/Article'),
      );
      expect(result.title, 'Article');
      expect(result.blocks.map((b) => b.kind), [
        'title',
        'text',
        'heading',
        'image',
        'caption',
      ]);
      expect(
        result.blocks[1].delta,
        contains(
          equals({
            'insert': 'science',
            'attributes': {'link': 'https://en.wikipedia.org/wiki/Science'},
          }),
        ),
      );
      expect(result.blocks[3].source, 'https://upload.wikimedia.org/pic.png');
    },
  );
}
