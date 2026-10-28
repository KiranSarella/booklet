import 'dart:io';

import 'package:booklet/importing/html_importer.dart';
import 'package:flutter_test/flutter_test.dart';

String text(HtmlImportBlock block) =>
    (block.delta ?? []).map((dynamic op) => (op as Map)['insert']).join();

void main() {
  final base = Uri.parse('https://example.com/docs/start/');
  test('extracts article, formatted text and exact code, excluding chrome', () {
    final result = HtmlImporter.parse('''
      <title>Site title</title><nav>Sidebar</nav><main><article>
      <h1>Quickstart<a class="hash-link">#</a></h1>
      <p>Hello <strong>world</strong> and <a href="../install/">install</a>.</p>
      <pre><code class="language-python">def main():
    print(&quot;Hi&quot;)

main()
</code></pre><script>bad()</script>
      </article><aside>On this page</aside></main><footer>Next page</footer>
    ''', baseUri: base);
    expect(result.title, 'Quickstart');
    expect(result.blocks.map((b) => b.kind), ['title', 'text', 'code_block']);
    expect(text(result.blocks[1]), 'Hello world and install.\n');
    expect(
      result.blocks[1].delta,
      contains(
        equals({
          'insert': 'world',
          'attributes': {'bold': true},
        }),
      ),
    );
    expect(
      result.blocks[1].delta,
      contains(
        equals({
          'insert': 'install',
          'attributes': {'link': 'https://example.com/docs/install/'},
        }),
      ),
    );
    expect(
      result.blocks.last.source,
      'def main():\n    print("Hi")\n\nmain()\n',
    );
    expect(result.blocks.last.language, 'python');
  });

  test('preserves article headers and syntax highlighted code lines', () {
    final result = HtmlImporter.parse(
      '''<header>Site menu</header><main><article>
      <header><h1>Article title</h1></header>
      <pre class="language-sh"><code><span class="token-line">echo hello</span><span class="token-line">  echo world</span></code></pre>
      </article></main>''',
      baseUri: base,
    );
    expect(result.title, 'Article title');
    expect(result.blocks.length, 2);
    expect(result.blocks.last.source, 'echo hello\n  echo world');
    expect(result.blocks.last.language, 'bash');
  });

  test('keeps list numbering, nesting, quotes and relative media', () {
    final result = HtmlImporter.parse('''<article><h1>Media</h1>
      <ol start="3"><li>Third<ul><li>Nested</li></ul></li><li value="8">Eighth</li></ol>
      <blockquote><p>A quote</p></blockquote>
      <p><img src="../image.png"></p><video><source src="/movie.mp4"></video>
      <iframe src="javascript:alert(1)"></iframe>
      </article>''', baseUri: base);
    expect(result.blocks[1].number, 3);
    expect(text(result.blocks[1]), 'Third\n');
    expect(result.blocks[2].depth, 1);
    expect(result.blocks[3].number, 8);
    expect(result.blocks[4].focusBar, isTrue);
    expect(result.blocks[5].source, 'https://example.com/docs/image.png');
    expect(result.blocks[6].source, 'https://example.com/movie.mp4');
    expect(result.blocks.length, 7);
  });

  test('resolves local media and base URLs', () {
    final local = HtmlImporter.parse(
      '<p>Local</p><img src="images/test.png">',
      baseUri: Uri.file('/tmp/docs/index.html'),
    );
    expect(local.blocks.last.source, 'file:///tmp/docs/images/test.png');
    final remote = HtmlImporter.parse(
      '<base href="/assets/"><img src="test.png">',
      baseUri: base,
    );
    expect(remote.blocks.single.source, 'https://example.com/assets/test.png');
  });

  test('rejects empty content and unsupported URL schemes', () async {
    expect(
      () => HtmlImporter.parse('<script>render()</script>', baseUri: base),
      throwsFormatException,
    );
    await expectLater(
      HtmlImporter.load(Uri.parse('javascript:alert(1)')),
      throwsFormatException,
    );
  });

  test(
    'loads localhost HTML, follows redirects and rejects non HTML',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        if (request.uri.path == '/redirect') {
          request.response.statusCode = 302;
          request.response.headers.set('location', '/docs/page');
        } else if (request.uri.path == '/binary') {
          request.response.headers.contentType = ContentType.binary;
        } else {
          request.response.headers.contentType = ContentType.html;
          request.response.write(
            '<article><h1>Local page</h1><img src="image.png"></article>',
          );
        }
        await request.response.close();
      });
      final origin = 'http://127.0.0.1:${server.port}';
      final result = await HtmlImporter.load(Uri.parse('$origin/redirect'));
      expect(result.title, 'Local page');
      expect(result.blocks.last.source, '$origin/docs/image.png');
      await expectLater(
        HtmlImporter.load(Uri.parse('$origin/binary')),
        throwsFormatException,
      );
    },
  );
}
