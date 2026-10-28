import 'dart:convert';
import 'dart:io';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

class HtmlImportBlock {
  HtmlImportBlock(
    this.kind, {
    this.delta,
    this.source,
    this.language,
    this.depth = 0,
    this.number,
    this.focusBar = false,
  });
  final String kind;
  final List<dynamic>? delta;
  final String? source;
  final String? language;
  final int depth;
  final int? number;
  final bool focusBar;
}

class HtmlImportResult {
  HtmlImportResult(this.title, this.blocks);
  final String title;
  final List<HtmlImportBlock> blocks;
}

/// Imports static content only; downloaded scripts are never executed.
class HtmlImporter {
  static const maxBytes = 10 * 1024 * 1024;

  static Future<HtmlImportResult> load(Uri uri) async {
    if (uri.scheme == 'file') {
      final file = File.fromUri(uri);
      if (await file.length() > maxBytes) {
        throw const FormatException('HTML file is too large (maximum 10 MB).');
      }
      return parse(await file.readAsString(), baseUri: uri);
    }
    if (!['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) {
      throw const FormatException('Enter an http:// or https:// URL.');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      return await (() async {
        final request = await client.getUrl(uri);
        request.headers.set(HttpHeaders.acceptHeader, 'text/html');
        final response = await request.close();
        if (response.statusCode != 200) {
          throw HttpException('Website returned HTTP ${response.statusCode}.');
        }
        final mime = response.headers.contentType?.mimeType;
        if (mime != null &&
            mime != 'text/html' &&
            mime != 'application/xhtml+xml') {
          throw const FormatException('This URL does not return an HTML page.');
        }
        final bytes = <int>[];
        await for (final chunk in response) {
          bytes.addAll(chunk);
          if (bytes.length > maxBytes) {
            throw const FormatException(
              'HTML page is too large (maximum 10 MB).',
            );
          }
        }
        var effectiveUri = uri;
        for (final redirect in response.redirects) {
          effectiveUri = effectiveUri.resolveUri(redirect.location);
        }
        final encoding =
            Encoding.getByName(
              response.headers.contentType?.charset ?? 'utf-8',
            ) ??
            utf8;
        return parse(encoding.decode(bytes), baseUri: effectiveUri);
      })().timeout(const Duration(seconds: 30));
    } finally {
      client.close(force: true);
    }
  }

  static HtmlImportResult parse(String source, {required Uri baseUri}) {
    final document = html.parse(source);
    final base = document.querySelector('base[href]')?.attributes['href'];
    if (base != null) baseUri = baseUri.resolve(base);
    for (final node in document.querySelectorAll(
      'script, style, noscript, nav, footer, aside, button, form, '
      '[hidden], [aria-hidden="true"], .hash-link, .header-anchor, '
      '.pagination-nav, .theme-doc-footer, .theme-doc-toc-mobile',
    )) {
      node.remove();
    }
    for (final header in document.querySelectorAll('header')) {
      var parent = header.parent;
      var inContent = false;
      while (parent != null) {
        if (parent.localName == 'article' ||
            parent.localName == 'main' ||
            parent.attributes['role'] == 'main') {
          inContent = true;
          break;
        }
        parent = parent.parent;
      }
      if (!inContent) header.remove();
    }
    final root =
        document.querySelector('main article') ??
        document.querySelector('article') ??
        document.querySelector('main') ??
        document.querySelector('[role="main"]') ??
        document.body;
    final title =
        root?.querySelector('h1')?.text.trim() ??
        document.querySelector('title')?.text.trim() ??
        'Imported HTML';
    final blocks = <HtmlImportBlock>[];

    String? resolve(String? value, {bool link = false}) {
      if (value == null || value.trim().isEmpty) return null;
      final uri = baseUri.resolve(value.trim());
      if (['http', 'https'].contains(uri.scheme) ||
          (uri.scheme == 'file' && baseUri.scheme == 'file') ||
          (link && uri.scheme == 'mailto')) {
        return uri.toString();
      }
      return null;
    }

    List<dynamic> inline(List<Node> nodes) {
      final ops = <Map<String, dynamic>>[];
      void visit(Node node, Map<String, dynamic> attrs) {
        if (node is Text) {
          var text = node.data.replaceAll(RegExp(r'\s+'), ' ');
          if (ops.isEmpty) text = text.trimLeft();
          if (ops.isNotEmpty && (ops.last['insert'] as String).endsWith(' ')) {
            text = text.replaceFirst(RegExp(r'^ +'), '');
          }
          if (text.isNotEmpty) {
            ops.add({
              'insert': text,
              if (attrs.isNotEmpty) 'attributes': attrs,
            });
          }
        } else if (node is Element) {
          final next = Map<String, dynamic>.of(attrs);
          switch (node.localName) {
            case 'strong':
            case 'b':
              next['bold'] = true;
            case 'em':
            case 'i':
              next['italic'] = true;
            case 'u':
              next['underline'] = true;
            case 's':
            case 'del':
              next['strike'] = true;
            case 'code':
              next['code'] = true;
            case 'a':
              final href = resolve(node.attributes['href'], link: true);
              if (href != null) next['link'] = href;
            case 'br':
              ops.add({'insert': '\n'});
              return;
          }
          for (final child in node.nodes) {
            visit(child, next);
          }
        }
      }

      for (final node in nodes) {
        visit(node, {});
      }
      if (ops.isNotEmpty) {
        ops.last['insert'] = (ops.last['insert'] as String).trimRight();
        ops.removeWhere((op) => op['insert'] == '');
      }
      return [
        ...ops,
        {'insert': '\n'},
      ];
    }

    void walk(Element element, {int depth = 0, bool quote = false}) {
      final tag = element.localName;
      if (tag == 'pre') {
        final code = element.querySelector('code') ?? element;
        final classes = '${element.className} ${code.className}';
        blocks.add(
          HtmlImportBlock(
            'code_block',
            source: code.querySelectorAll('.token-line').isNotEmpty
                ? code
                      .querySelectorAll('.token-line')
                      .map((line) => line.text)
                      .join('\n')
                : code.text,
            language: switch (RegExp(r'language-([\w+-]+)')
                .firstMatch(classes)
                ?.group(1)) {
              'sh' || 'shell' => 'bash',
              final language => language,
            },
          ),
        );
        return;
      }
      if (['img', 'video', 'audio'].contains(tag)) {
        final url = resolve(
          element.attributes['src'] ??
              element.attributes['data-src'] ??
              element.querySelector('source')?.attributes['src'],
        );
        if (url != null) {
          blocks.add(
            HtmlImportBlock(tag == 'img' ? 'image' : tag!, source: url),
          );
        }
        return;
      }
      if (tag == 'iframe') {
        final url = resolve(element.attributes['src']);
        if (url != null) blocks.add(HtmlImportBlock('link', source: url));
        return;
      }
      if (tag == 'ul' || tag == 'ol') {
        var number = int.tryParse(element.attributes['start'] ?? '') ?? 1;
        for (final item in element.children.where((e) => e.localName == 'li')) {
          final value = int.tryParse(item.attributes['value'] ?? '') ?? number;
          final content = item.clone(true);
          for (final nested in content.querySelectorAll('ul, ol, pre')) {
            nested.remove();
          }
          final delta = inline(content.nodes);
          if (delta.length > 1) {
            blocks.add(
              HtmlImportBlock(
                tag == 'ol' ? 'numbered_list' : 'bulleted_list',
                delta: delta,
                depth: depth,
                number: tag == 'ol' ? value : null,
                focusBar: quote,
              ),
            );
          }
          for (final nested in item.children.where(
            (e) => ['ul', 'ol', 'pre'].contains(e.localName),
          )) {
            walk(nested, depth: depth + 1, quote: quote);
          }
          number = value + 1;
        }
        return;
      }
      final kind = switch (tag) {
        'h1' => 'title',
        'h2' => 'heading',
        'h3' => 'subheading',
        'h4' || 'h5' || 'h6' => 'inline_heading',
        'figcaption' => 'caption',
        'p' || 'dt' || 'dd' => 'text',
        _ => null,
      };
      if (kind != null) {
        final delta = inline(element.nodes);
        if (delta.length > 1) {
          blocks.add(HtmlImportBlock(kind, delta: delta, focusBar: quote));
        }
        for (final media in element.querySelectorAll(
          'img, video, audio, iframe',
        )) {
          walk(media);
        }
        return;
      }
      final pending = <Node>[];
      void flush() {
        final delta = inline(pending);
        if (delta.length > 1) {
          blocks.add(HtmlImportBlock('text', delta: delta, focusBar: quote));
        }
        pending.clear();
      }

      const containers = {
        'div',
        'section',
        'article',
        'main',
        'blockquote',
        'ul',
        'ol',
        'pre',
        'p',
        'h1',
        'h2',
        'h3',
        'h4',
        'h5',
        'h6',
        'img',
        'video',
        'audio',
        'iframe',
        'figure',
        'figcaption',
        'table',
        'thead',
        'tbody',
        'tr',
        'td',
        'th',
        'dl',
        'dt',
        'dd',
      };
      for (final child in element.nodes) {
        if (child is Element && containers.contains(child.localName)) {
          flush();
          walk(child, depth: depth, quote: quote || tag == 'blockquote');
        } else {
          pending.add(child);
        }
      }
      flush();
    }

    if (root != null) walk(root);
    if (blocks.isEmpty) {
      throw const FormatException(
        'No readable content found. The page may require JavaScript or sign-in.',
      );
    }
    return HtmlImportResult(title.isEmpty ? 'Imported HTML' : title, blocks);
  }
}
