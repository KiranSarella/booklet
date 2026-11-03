import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';

import 'html_importer.dart';

class DocxImporter {
  static const maxBytes = 50 * 1024 * 1024;
  static const maxExpandedBytes = 200 * 1024 * 1024;
  static const _word =
      'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
  static const _rel =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

  static Future<HtmlImportResult> load(
    String path, {
    Directory? assetRoot,
  }) async {
    final file = File(path);
    if (await file.length() > maxBytes) {
      throw const FormatException('DOCX file is too large (maximum 50 MB).');
    }
    final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
    if (archive.length > 10000 ||
        archive.fold<int>(0, (sum, e) => sum + e.size) > maxExpandedBytes) {
      throw const FormatException('DOCX expanded content is too large.');
    }
    final entries = {for (final e in archive.where((e) => e.isFile)) e.name: e};
    XmlDocument? xml(String name) {
      final entry = entries[name];
      return entry == null
          ? null
          : XmlDocument.parse(utf8.decode(entry.content));
    }

    final document = xml('word/document.xml');
    if (document == null) {
      throw const FormatException(
        'This is not a supported DOCX document. Save encrypted or legacy Word files as an unencrypted .docx first.',
      );
    }
    final relationships = {
      for (final e
          in xml('word/_rels/document.xml.rels')?.rootElement.childElements ??
              <XmlElement>[])
        e.getAttribute('Id'): e,
    };
    final styles = {
      for (final e
          in xml('word/styles.xml')?.rootElement.childElements ??
              <XmlElement>[])
        e.getAttribute('styleId', namespaceUri: _word): e,
    };
    final numbering = xml('word/numbering.xml');
    final nums = {
      for (final e in numbering?.rootElement.childElements ?? <XmlElement>[])
        if (e.name.local == 'num')
          e.getAttribute('numId', namespaceUri: _word): e,
    };
    final abstracts = {
      for (final e in numbering?.rootElement.childElements ?? <XmlElement>[])
        if (e.name.local == 'abstractNum')
          e.getAttribute('abstractNumId', namespaceUri: _word): e,
    };
    String? value(XmlElement? e) => e?.getAttribute('val', namespaceUri: _word);
    XmlElement? child(XmlElement? e, String name) =>
        e?.getElement(name, namespaceUri: _word);
    bool enabled(XmlElement? e) =>
        e != null && !{'0', 'false', 'off', 'none'}.contains(value(e));
    const escape = HtmlEscape();
    Directory? assets;
    final imagePaths = <String, String>{};
    try {
      Future<String?> image(String? id) async {
        final relationship = relationships[id];
        if (relationship == null ||
            relationship.getAttribute('TargetMode') == 'External') {
          return null;
        }
        final target = Uri.parse('word/document.xml')
            .resolve(relationship.getAttribute('Target') ?? '');
        if (target.hasScheme || target.hasAuthority) return null;
        final entry = entries[target.path];
        if (entry == null || !target.path.startsWith('word/media/')) {
          return null;
        }
        if (imagePaths.containsKey(target.path)) return imagePaths[target.path];
        final extension = target.path.split('.').last.toLowerCase();
        if (!{'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'}.contains(extension)) {
          return null;
        }
        if (assets == null) {
          final root =
              assetRoot ??
              Directory(
                '${(await getApplicationSupportDirectory()).path}/docx_imports',
              );
          await root.create(recursive: true);
          assets = await root.createTemp('import_');
        }
        final output = File(
          '${assets!.path}/image_${imagePaths.length}.$extension',
        );
        await output.writeAsBytes(entry.content);
        return imagePaths[target.path] = output.uri.toString();
      }

      Future<String> inline(XmlElement e) async {
        if (e.name.namespaceUri == _word) {
          switch (e.name.local) {
            case 'del':
            case 'moveFrom':
            case 'instrText':
            case 'pPr':
            case 'rPr':
              return '';
            case 't':
              return escape.convert(e.innerText);
            case 'tab':
              return '    ';
            case 'br':
            case 'cr':
              return '<br>';
          }
        }
        if (e.name.local == 'blip') {
          final source = await image(
            e.getAttribute('embed', namespaceUri: _rel),
          );
          return source == null ? '' : '<img src="${escape.convert(source)}">';
        }
        var content = '';
        for (final element in e.childElements) {
          content += await inline(element);
        }
        if (e.name.local == 'r') {
          final properties = child(e, 'rPr');
          for (final format in {
            'b': 'strong',
            'i': 'em',
            'u': 'u',
            'strike': 's',
          }.entries) {
            if (enabled(child(properties, format.key))) {
              content = '<${format.value}>$content</${format.value}>';
            }
          }
        }
        if (e.name.local == 'hyperlink') {
          final target = relationships[e.getAttribute('id', namespaceUri: _rel)]
              ?.getAttribute('Target');
          final uri = Uri.tryParse(target ?? '');
          if (uri != null && {'https', 'http', 'mailto'}.contains(uri.scheme)) {
            content = '<a href="${escape.convert(target!)}">$content</a>';
          }
        }
        return content;
      }

      final blocks = <HtmlImportBlock>[];
      final counters = <String, int>{};
      final body = document
          .findAllElements('body', namespaceUri: _word)
          .firstOrNull;
      if (body == null) {
        throw const FormatException('DOCX has no document body.');
      }
      // Paragraph traversal also retains table-cell text in document order.
      for (final paragraph in body.descendants.whereType<XmlElement>().where(
        (e) => e.name.namespaceUri == _word && e.name.local == 'p',
      )) {
        final properties = child(paragraph, 'pPr');
        final styleId = value(child(properties, 'pStyle'));
        final style = styles[styleId];
        final styleName = value(child(style, 'name')) ?? styleId ?? '';
        final outline = int.tryParse(
          value(child(properties, 'outlineLvl')) ??
              value(child(child(style, 'pPr'), 'outlineLvl')) ??
              '',
        );
        final heading = int.tryParse(
          RegExp(
                r'heading\s*(\d)',
                caseSensitive: false,
              ).firstMatch(styleName)?.group(1) ??
              '',
        );
        final tag = styleName.toLowerCase() == 'title'
            ? 'h1'
            : heading != null
            ? 'h${heading.clamp(1, 6)}'
            : outline != null && outline < 6
            ? 'h${outline + 1}'
            : 'p';
        final content = await inline(paragraph);
        if (content.replaceAll(RegExp(r'<[^>]*>'), '').trim().isEmpty &&
            !content.contains('<img')) {
          continue;
        }
        final parsed = HtmlImporter.parse(
          '<$tag>$content</$tag>',
          baseUri: Uri.file(path),
        );
        final numPr =
            child(properties, 'numPr') ?? child(child(style, 'pPr'), 'numPr');
        final numId = value(child(numPr, 'numId'));
        final depth = int.tryParse(value(child(numPr, 'ilvl')) ?? '') ?? 0;
        final abstractId = value(child(nums[numId], 'abstractNumId'));
        final level = abstracts[abstractId]?.childElements
            .where(
              (e) =>
                  e.name.local == 'lvl' &&
                  e.getAttribute('ilvl', namespaceUri: _word) == '$depth',
            )
            .firstOrNull;
        final override = nums[numId]?.childElements
            .where(
              (e) =>
                  e.name.local == 'lvlOverride' &&
                  e.getAttribute('ilvl', namespaceUri: _word) == '$depth',
            )
            .firstOrNull;
        final numbered = value(child(level, 'numFmt')) != 'bullet';
        int? number;
        if (numId != null && numId != '0' && numbered) {
          final key = '$numId:$depth';
          number =
              counters[key] ??
              int.tryParse(
                value(child(override, 'startOverride')) ??
                    value(child(level, 'start')) ??
                    '',
              ) ??
              1;
          counters[key] = number + 1;
          counters.removeWhere(
            (k, _) =>
                k.startsWith('$numId:') &&
                (int.tryParse(k.split(':').last) ?? 0) > depth,
          );
        }
        for (final block in parsed.blocks) {
          blocks.add(
            numId != null && numId != '0' && block.delta != null
                ? HtmlImportBlock(
                    numbered ? 'numbered_list' : 'bulleted_list',
                    delta: block.delta,
                    depth: depth,
                    number: number,
                  )
                : block,
          );
        }
      }
      if (blocks.isEmpty) {
        throw const FormatException('DOCX has no readable content.');
      }
      final title = xml('docProps/core.xml')?.descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == 'title')
          .map((e) => e.innerText.trim())
          .where((s) => s.isNotEmpty)
          .firstOrNull;
      return HtmlImportResult(
        title ??
            file.uri.pathSegments.last.replaceFirst(
              RegExp(r'\.docx$', caseSensitive: false),
              '',
            ),
        blocks,
      );
    } catch (_) {
      if (assets != null) await assets!.delete(recursive: true);
      rethrow;
    }
  }
}
