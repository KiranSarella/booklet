import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';

import 'html_importer.dart';

class EpubImportResult {
  const EpubImportResult(this.title, this.chapters);
  final String title;
  final List<HtmlImportResult> chapters;
}

/// Reads EPUB package metadata and spine without executing book content.
class EpubImporter {
  static const maxBytes = 50 * 1024 * 1024;
  static const maxExpandedBytes = 200 * 1024 * 1024;

  static Future<EpubImportResult> load(
    String path, {
    Directory? assetRoot,
  }) async {
    final file = File(path);
    if (await file.length() > maxBytes) {
      throw const FormatException('EPUB file is too large (maximum 50 MB).');
    }
    final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
    if (archive.length > 10000 ||
        archive.fold<int>(0, (sum, entry) => sum + entry.size) >
            maxExpandedBytes) {
      throw const FormatException('EPUB expanded content is too large.');
    }
    // Validate every path before writing any content outside the archive.
    final entries = <String, ArchiveFile>{};
    for (final entry in archive) {
      final uri = Uri.tryParse(entry.name);
      if (uri == null ||
          uri.hasScheme ||
          uri.hasAuthority ||
          entry.name.contains('\\') ||
          entry.name.startsWith('/') ||
          uri.path.split('/').any((part) => part == '..' || part == '.')) {
        throw const FormatException('EPUB contains an unsafe file path.');
      }
      if (entry.isFile) entries[uri.path] = entry;
    }
    String read(String name) {
      final entry = entries[name];
      if (entry == null) throw FormatException('EPUB is missing $name.');
      return utf8.decode(entry.content);
    }

    final container = XmlDocument.parse(read('META-INF/container.xml'));
    final packagePath = container.descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == 'rootfile')
        .map((e) => e.getAttribute('full-path'))
        .firstOrNull;
    if (packagePath == null) {
      throw const FormatException('EPUB has no package document.');
    }
    if (entries.containsKey('META-INF/encryption.xml')) {
      final encryption = XmlDocument.parse(read('META-INF/encryption.xml'));
      // Font obfuscation is common in otherwise unencrypted EPUBs.
      for (final method in encryption.descendants.whereType<XmlElement>().where(
        (e) => e.name.local == 'EncryptionMethod',
      )) {
        if (!{
          'http://www.idpf.org/2008/embedding',
          'http://ns.adobe.com/pdf/enc#RC',
        }.contains(method.getAttribute('Algorithm'))) {
          throw const FormatException('DRM-protected EPUBs are not supported.');
        }
      }
    }
    final package = XmlDocument.parse(read(packagePath));
    final elements = package.descendants.whereType<XmlElement>().toList();
    final title =
        elements
            .where((e) => e.name.local == 'title')
            .map((e) => e.innerText.trim())
            .where((s) => s.isNotEmpty)
            .firstOrNull ??
        file.uri.pathSegments.last.replaceFirst(
          RegExp(r'\.epub$', caseSensitive: false),
          '',
        );
    final manifest = {
      for (final e in elements.where((e) => e.name.local == 'item'))
        e.getAttribute('id'): e,
    };
    final spine = elements
        .where(
          (e) => e.name.local == 'itemref' && e.getAttribute('linear') != 'no',
        )
        .toList();
    Directory? assets;
    try {
      final root =
          assetRoot ??
          Directory(
            '${(await getApplicationSupportDirectory()).path}/epub_imports',
          );
      await root.create(recursive: true);
      assets = await root.createTemp('import_');
      // Extract into a persistent directory so relative image and chapter links
      // remain valid after importing and reopening the document.
      for (final entry in entries.entries) {
        final target = File('${assets.path}/${entry.key}');
        await target.parent.create(recursive: true);
        await target.writeAsBytes(entry.value.content);
      }
      final chapters = <HtmlImportResult>[];
      for (final ref in spine) {
        final item = manifest[ref.getAttribute('idref')];
        final href = item?.getAttribute('href');
        if (href == null) {
          throw const FormatException('EPUB has a broken chapter reference.');
        }
        if (!{
          'application/xhtml+xml',
          'text/html',
        }.contains(item?.getAttribute('media-type'))) {
          continue;
        }
        final chapterUri = Uri(path: packagePath).resolve(href);
        if (chapterUri.hasScheme ||
            chapterUri.hasAuthority ||
            !entries.containsKey(chapterUri.path)) {
          throw const FormatException('EPUB chapter is missing or invalid.');
        }
        final baseUri = assets.uri.resolveUri(chapterUri);
        chapters.add(
          HtmlImporter.parse(read(chapterUri.path), baseUri: baseUri),
        );
      }
      if (chapters.isEmpty) {
        throw const FormatException('EPUB has no readable chapters.');
      }
      return EpubImportResult(title, chapters);
    } catch (_) {
      if (assets != null) await assets.delete(recursive: true);
      rethrow;
    }
  }
}
