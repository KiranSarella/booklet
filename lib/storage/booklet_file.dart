import 'dart:convert';
import 'dart:io';

import 'package:booklet/business/page_content.dart';
import 'package:booklet/storage/rich_text_codec.dart';
import 'package:booklet/ui/components/inbuilt_components.dart';
import 'package:booklet/ui/editor_themes/editor_themes.dart';
import 'package:booklet/ui/navigation/navigation_node.dart';
import 'package:file_selector/file_selector.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_quill/flutter_quill.dart';

class BookletManifest {
  const BookletManifest({
    required this.path,
    required this.groups,
    required this.selectedPageId,
  });

  final String path;
  final List<NavigationNode> groups;
  final String? selectedPageId;
}

class BookletFile {
  static const _extension = 'booklet';
  static const _manifestName = 'content.json';
  static const _pagesDirectory = 'pages';
  static const _mediaDirectory = 'media';

  static Future<String?> chooseSavePath() async {
    final location = await getSaveLocation(suggestedName: 'Untitled.booklet');
    if (location == null) {
      return null;
    }
    return _normalizePackagePath(location.path);
  }

  static Future<BookletManifest?> openManifest() async {
    final file = await openFile();
    if (file == null) {
      return null;
    }

    final selectedPath = file.path;
    final packagePath = FileSystemEntity.isDirectorySync(selectedPath)
        ? selectedPath
        : File(selectedPath).parent.path;
    final manifest = File('$packagePath/$_manifestName');
    final json = jsonDecode(await manifest.readAsString());
    if (json is! Map) {
      throw const FormatException('Invalid booklet manifest');
    }

    final navigationData = json['navigation'];
    if (navigationData is! List) {
      throw const FormatException('Invalid booklet navigation');
    }
    await _migrateLegacyPages(packagePath, json['pages']);

    return BookletManifest(
      path: packagePath,
      groups: navigationData
          .whereType<Map>()
          .map(
            (group) =>
                NavigationNode.fromJson(Map<String, dynamic>.from(group)),
          )
          .toList(),
      selectedPageId: json['selectedPageId'] as String?,
    );
  }

  static Future<PageContent> loadPage(
    String packagePath,
    String pageId,
    EditorTheme theme,
  ) async {
    final pageFile = File('$packagePath/$_pagesDirectory/$pageId.json');
    final json = jsonDecode(await pageFile.readAsString());
    if (json is! Map) {
      throw const FormatException('Invalid page content');
    }

    final pageJson = Map<String, dynamic>.from(json);
    final components = <ComponentBox>[];
    final rawComponents = pageJson['components'];
    if (rawComponents is List) {
      for (final rawComponent in rawComponents.whereType<Map>()) {
        final componentJson = Map<String, dynamic>.from(rawComponent);
        final type = componentJson['type'] as String?;
        if (type == null) {
          continue;
        }

        List<dynamic>? delta;
        if (componentJson.containsKey('content') ||
            componentJson.containsKey('styles') ||
            componentJson.containsKey('text') ||
            componentJson.containsKey('spans')) {
          final richText = RichTextData.fromJson(componentJson);
          delta = RichTextCodec.richTextToDelta(richText);
        } else if (componentJson['delta'] is List) {
          delta = componentJson['delta'] as List<dynamic>;
        }

        final id = componentJson['id'] as String? ?? const Uuid().v4();
        final component = InbuiltComponents.prepareCompoent(id, type);
        final componentState = component.state;
        if (componentState is ImageComponentState) {
          final mediaPath = componentJson['mediaPath'] as String?;
          componentState.mediaPath = _resolvePackageMediaPath(
            packagePath,
            mediaPath,
          );
          componentState.imageSize =
              (componentJson['imageSize'] as String?) ?? 'medium';
          final width = componentJson['width'];
          final height = componentJson['height'];
          componentState.width = width is num ? width.toInt() : null;
          componentState.height = height is num ? height.toInt() : null;
        } else if (componentState is QuoteComponentState &&
            componentJson['author'] is String) {
          final authorData = RichTextData.fromJson({
            'content': componentJson['author'],
            'styles': componentJson['authorStyles'],
          });
          componentState.author.controller.document = Document.fromJson(
            RichTextCodec.richTextToDelta(authorData),
          );
        }
        components.add(
          ComponentBox(
            component: component,
            delta: delta,
          ),
        );
      }
    }

    return PageContent(
      id: pageJson['id'] as String? ?? pageId,
      title: pageJson['title'] as String? ?? 'Untitled page',
      components: components,
    );
  }

  static Future<void> saveManifest({
    required String packagePath,
    required List<NavigationNode> groups,
    required String? selectedPageId,
  }) async {
    await _ensurePackageDirectories(packagePath);
    final json = const JsonEncoder.withIndent('  ').convert({
      'version': 1,
      'selectedPageId': selectedPageId,
      'navigation': groups.map((group) => group.toJson()).toList(),
    });
    await File('$packagePath/$_manifestName').writeAsString(json);
  }

  static Future<void> savePage(String packagePath, PageContent page) async {
    await _ensurePackageDirectories(packagePath);

    final componentJson = <Map<String, dynamic>>[];
    for (final componentBox in page.components) {
      final state = componentBox.component.state;
      if (state is TextComponentState) {
        final delta = state.controller.document.toDelta().toJson();
        final richText = RichTextCodec.deltaToRichText(delta);
        componentJson.add({
          'id': componentBox.component.id,
          'type': componentBox.component.def.key,
          'content': richText.content,
          'styles': richText.styles.map((s) => s.toJson()).toList(),
        });
        continue;
      }
      if (state is QuoteComponentState) {
        final quote = RichTextCodec.deltaToRichText(
          state.quote.controller.document.toDelta().toJson(),
        );
        final author = RichTextCodec.deltaToRichText(
          state.author.controller.document.toDelta().toJson(),
        );
        componentJson.add({
          'id': componentBox.component.id,
          'type': componentBox.component.def.key,
          'content': quote.content,
          'styles': quote.styles.map((s) => s.toJson()).toList(),
          'author': author.content,
          'authorStyles': author.styles.map((s) => s.toJson()).toList(),
        });
        continue;
      }
      if (state is ImageComponentState) {
        final asset = await _persistImageAsset(packagePath, state);
        componentJson.add({
          'id': componentBox.component.id,
          'type': componentBox.component.def.key,
          'mediaPath': asset['mediaPath'],
          'imageSize': state.imageSize ?? 'medium',
          'width': asset['width'],
          'height': asset['height'],
        });
        continue;
      }
      throw StateError('Unsupported component state');
    }

    final json = const JsonEncoder.withIndent('  ').convert({
      'id': page.id,
      'title': page.title,
      'components': componentJson,
    });
    await File('$packagePath/$_pagesDirectory/${page.id}.json')
        .writeAsString(json);
  }

  static String _normalizePackagePath(String path) =>
      path.endsWith('.$_extension') ? path : '$path.$_extension';

  static Future<Map<String, dynamic>> _persistImageAsset(
    String packagePath,
    ImageComponentState state,
  ) async {
    final sourcePath = state.mediaPath;
    if (sourcePath == null || sourcePath.isEmpty) {
      return {
        'mediaPath': null,
        'imageSize': state.imageSize ?? 'medium',
        'width': state.width,
        'height': state.height,
      };
    }

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      return {
        'mediaPath': _resolvePackageMediaPath(packagePath, sourcePath),
        'imageSize': state.imageSize ?? 'medium',
        'width': state.width,
        'height': state.height,
      };
    }

    final extension = _imageExtension(sourcePath) ?? 'png';
    final mediaDirectory = Directory('$packagePath/$_mediaDirectory');
    await mediaDirectory.create(recursive: true);

    final targetPath = '${mediaDirectory.path}/${const Uuid().v4()}.$extension';
    final targetFile = File(targetPath);
    await sourceFile.copy(targetFile.path);

    final relativePath = _toPackageMediaPath(packagePath, targetFile.path);
    state.mediaPath = targetFile.path;
    return {
      'mediaPath': relativePath,
      'imageSize': state.imageSize ?? 'medium',
      'width': state.width,
      'height': state.height,
    };
  }

  static String? _resolvePackageMediaPath(String packagePath, String? mediaPath) {
    if (mediaPath == null || mediaPath.isEmpty) {
      return null;
    }
    if (mediaPath.startsWith('media/') || mediaPath.startsWith('media\\')) {
      return '$packagePath/${mediaPath.replaceAll('\\', '/')}';
    }
    if (FileSystemEntity.isFileSync(mediaPath)) {
      return mediaPath;
    }
    final normalizedMediaPath = mediaPath.replaceAll('\\', '/');
    if (normalizedMediaPath.startsWith('/')) {
      return normalizedMediaPath;
    }
    return '$packagePath/$normalizedMediaPath';
  }

  static String _toPackageMediaPath(String packagePath, String absolutePath) {
    final normalizedPackagePath = packagePath.replaceAll('\\', '/');
    final normalizedAbsolutePath = absolutePath.replaceAll('\\', '/');
    return normalizedAbsolutePath.startsWith('$normalizedPackagePath/')
        ? normalizedAbsolutePath.substring(normalizedPackagePath.length + 1)
        : normalizedAbsolutePath;
  }

  static String? _imageExtension(String path) {
    final extension = path.split('.').last.toLowerCase();
    if (extension.isEmpty) {
      return null;
    }
    return extension;
  }

  static Future<void> _migrateLegacyPages(
    String packagePath,
    dynamic legacyPages,
  ) async {
    if (legacyPages is! List) {
      return;
    }
    final pagesDirectory = Directory('$packagePath/$_pagesDirectory');
    await pagesDirectory.create(recursive: true);
    for (final rawPage in legacyPages.whereType<Map>()) {
      final page = Map<String, dynamic>.from(rawPage);
      final pageId = page['id'] as String?;
      if (pageId == null || pageId.isEmpty) {
        continue;
      }
      final pageFile = File('${pagesDirectory.path}/$pageId.json');
      if (!await pageFile.exists()) {
        await pageFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(page),
        );
      }
    }
  }

  static Future<void> _ensurePackageDirectories(String packagePath) async {
    await Directory(packagePath).create(recursive: true);
    await Directory('$packagePath/$_pagesDirectory').create(recursive: true);
    await Directory('$packagePath/$_mediaDirectory').create(recursive: true);
    await Directory('$packagePath/custom_components').create(recursive: true);
    await Directory('$packagePath/metadata').create(recursive: true);
  }
}
