import 'dart:convert';
import 'dart:io';

import 'package:booklet/business/page_content.dart';
import 'package:booklet/business/booklet_asset.dart';
import 'package:booklet/storage/rich_text_codec.dart';
import 'package:booklet/ui/components/inbuilt_components.dart';
import 'package:booklet/ui/components/code_block_component.dart';
import 'package:booklet/ui/components/math_component.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/ui/sidebar/pages_navigation/navigation_node.dart';
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
    required this.selectedAssetFolderId,
  });

  final String path;
  final List<NavigationNode> groups;
  final String? selectedPageId;
  final String? selectedAssetFolderId;
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
    return loadManifestAtPath(packagePath);
  }

  static Future<BookletManifest> loadManifestAtPath(String packagePath) async {
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

    final groups = navigationData
        .whereType<Map>()
        .map(
          (group) => NavigationNode.fromJson(Map<String, dynamic>.from(group)),
        )
        .toList();
    for (final group in groups) {
      await _loadAssetIndexes(packagePath, group);
    }

    return BookletManifest(
      path: packagePath,
      groups: groups,
      selectedPageId: json['selectedPageId'] as String?,
      selectedAssetFolderId: json['selectedAssetFolderId'] as String?,
    );
  }

  static const _assetIndexName = 'index.json';

  static Future<void> _loadAssetIndexes(
    String packagePath,
    NavigationNode node,
  ) async {
    final folderId = node.folderId;
    if (node.isAssetsFolder && folderId != null) {
      final indexFile = File('$packagePath/assets/$folderId/$_assetIndexName');
      if (await indexFile.exists()) {
        final raw = jsonDecode(await indexFile.readAsString());
        node.assets.clear();
        if (raw is List) {
          for (final entry in raw.whereType<Map>()) {
            final id = entry['id'] as String? ?? '';
            final name = entry['name'] as String? ?? 'Untitled file';
            node.assets.add(
              BookletAsset(
                id: id,
                name: name,
                path: 'assets/$folderId/$id${_assetExtension(name)}',
              ),
            );
          }
        }
      }
    }
    for (final child in node.children) {
      await _loadAssetIndexes(packagePath, child);
    }
  }

  static Future<List<XFile>> chooseAssets() => openFiles();

  static Future<List<BookletAsset>> importAssets({
    required String? packagePath,
    required String folderId,
    required List<XFile> files,
  }) async {
    final assets = <BookletAsset>[];
    final assetDirectory = packagePath == null
        ? null
        : Directory('$packagePath/assets/$folderId');
    await assetDirectory?.create(recursive: true);

    for (final file in files) {
      final id = const Uuid().v4();
      final asset = BookletAsset(
        id: id,
        name: file.name,
        path: assetDirectory == null
            ? file.path
            : 'assets/$folderId/$id${_assetExtension(file.name)}',
      );
      if (assetDirectory != null) {
        await file.saveTo(
          '${assetDirectory.path}/$id${_assetExtension(file.name)}',
        );
      }
      assets.add(asset);
    }
    return assets;
  }

  static Future<void> deleteAssetsForNode(
    String? packagePath,
    NavigationNode node,
  ) async {
    if (packagePath == null) {
      return;
    }
    final folderId = node.folderId;
    if (folderId != null) {
      final directory = Directory('$packagePath/assets/$folderId');
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
    for (final child in node.children) {
      await deleteAssetsForNode(packagePath, child);
    }
  }

  static Future<Map<String, dynamic>> exportNavigationSubtree({
    required String? packagePath,
    required NavigationNode node,
    required Iterable<PageContent> loadedPages,
    required PageSettingsController theme,
  }) async {
    final temporaryPackage = await Directory.systemTemp.createTemp(
      'booklet_navigation_copy',
    );
    final loadedPagesById = {for (final page in loadedPages) page.id: page};
    final pages = <String, dynamic>{};
    final resources = <String, String>{};

    try {
      for (final pageNode in _pageNodes(node)) {
        final pageId = pageNode.pageId!;
        final loadedPage = loadedPagesById[pageId];
        if (loadedPage != null) {
          await _savePagePreservingMediaPaths(
            temporaryPackage.path,
            loadedPage,
          );
        } else if (packagePath != null) {
          final page = await loadPage(packagePath, pageId, theme);
          try {
            await _savePagePreservingMediaPaths(temporaryPackage.path, page);
          } finally {
            page.dispose();
          }
        } else {
          await _ensurePackageDirectories(temporaryPackage.path);
          await File('${temporaryPackage.path}/$_pagesDirectory/$pageId.json')
              .writeAsString(
                jsonEncode({
                  'id': pageId,
                  'title': pageNode.title,
                  'components': [],
                }),
              );
        }

        final pageFile = File(
          '${temporaryPackage.path}/$_pagesDirectory/$pageId.json',
        );
        pages[pageId] = jsonDecode(await pageFile.readAsString());
      }

      final mediaDirectory = Directory(
        '${temporaryPackage.path}/$_mediaDirectory',
      );
      if (await mediaDirectory.exists()) {
        await for (final entity in mediaDirectory.list(recursive: true)) {
          if (entity is File) {
            final relativePath = entity.path
                .substring(temporaryPackage.path.length + 1)
                .replaceAll('\\', '/');
            resources[relativePath] = base64Encode(await entity.readAsBytes());
          }
        }
      }

      final assetFiles = <String, String>{};
      for (final folder in _assetFolderNodes(node)) {
        for (final asset in folder.assets) {
          final sourcePath = File(asset.path).isAbsolute || packagePath == null
              ? asset.path
              : '$packagePath/${asset.path}';
          final sourceFile = File(sourcePath);
          if (await sourceFile.exists()) {
            assetFiles['${folder.folderId}/${asset.id}'] = base64Encode(
              await sourceFile.readAsBytes(),
            );
          }
        }
      }

      return {
        'node': node.toJson(),
        'pages': pages,
        'resources': resources,
        'assetFiles': assetFiles,
      };
    } finally {
      await temporaryPackage.delete(recursive: true);
    }
  }

  static Future<String> importNavigationSubtree({
    required String packagePath,
    required NavigationNode sourceNode,
    required NavigationNode copiedNode,
    required Map<String, dynamic> bundle,
    required bool useAbsoluteAssetPaths,
  }) async {
    await _ensurePackageDirectories(packagePath);
    final pages = Map<String, dynamic>.from(
      bundle['pages'] as Map? ?? const {},
    );
    final resources = Map<String, dynamic>.from(
      bundle['resources'] as Map? ?? const {},
    );
    final assetFiles = Map<String, dynamic>.from(
      bundle['assetFiles'] as Map? ?? const {},
    );
    final pageIds = <String, String>{};
    _pairNavigationNodes(
      sourceNode,
      copiedNode,
      pageIds,
      assetFiles,
      packagePath,
      useAbsoluteAssetPaths,
    );

    for (final entry in pageIds.entries) {
      final rawPage = pages[entry.key];
      if (rawPage is! Map) {
        continue;
      }
      final page = Map<String, dynamic>.from(rawPage);
      page['id'] = entry.value;
      final copiedPageNode = _findPageNode(copiedNode, entry.value);
      if (copiedPageNode != null) {
        page['title'] = copiedPageNode.title;
      }
      final components = page['components'];
      if (components is List) {
        for (final rawComponent in components.whereType<Map>()) {
          final component = Map<String, dynamic>.from(rawComponent);
          component['id'] = const Uuid().v4();
          final mediaPath = component['mediaPath'];
          final encodedMedia = mediaPath is String
              ? resources[mediaPath]
              : null;
          if (mediaPath is String && encodedMedia is String) {
            final extension = _mediaExtension(mediaPath) ?? 'bin';
            final targetRelativePath =
                '$_mediaDirectory/${const Uuid().v4()}.$extension';
            final targetFile = File('$packagePath/$targetRelativePath');
            await targetFile.parent.create(recursive: true);
            await targetFile.writeAsBytes(base64Decode(encodedMedia));
            component['mediaPath'] = targetRelativePath;
          }
          components[components.indexOf(rawComponent)] = component;
        }
      }
      await File('$packagePath/$_pagesDirectory/${entry.value}.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert(page));
    }
    return packagePath;
  }

  static Future<void> copyStagedNavigationPages(
    String targetPackagePath,
    String stagedPackagePath,
    NavigationNode subtree,
  ) async {
    for (final pageNode in _pageNodes(subtree)) {
      final sourceFile = File(
        '$stagedPackagePath/$_pagesDirectory/${pageNode.pageId}.json',
      );
      if (await sourceFile.exists()) {
        await sourceFile.copy(
          '$targetPackagePath/$_pagesDirectory/${pageNode.pageId}.json',
        );
      }
    }
    final sourceMedia = Directory('$stagedPackagePath/$_mediaDirectory');
    if (await sourceMedia.exists()) {
      await for (final entity in sourceMedia.list(recursive: true)) {
        if (entity is File) {
          final relativePath = entity.path.substring(
            stagedPackagePath.length + 1,
          );
          final targetFile = File('$targetPackagePath/$relativePath');
          await targetFile.parent.create(recursive: true);
          await entity.copy(targetFile.path);
        }
      }
    }
  }

  static Future<void> _savePagePreservingMediaPaths(
    String packagePath,
    PageContent page,
  ) async {
    final originalPaths = <Object, String?>{};
    for (final box in page.components) {
      final state = box.component.state;
      if (state is ImageComponentState ||
          state is VideoComponentState ||
          state is AudioComponentState) {
        originalPaths[state] = _mediaPathOf(state);
      }
    }
    try {
      await savePage(packagePath, page);
    } finally {
      for (final box in page.components) {
        final state = box.component.state;
        if (state is ImageComponentState ||
            state is VideoComponentState ||
            state is AudioComponentState) {
          _setMediaPath(state, originalPaths[state]);
        }
      }
    }
  }

  static String? _mediaPathOf(Object state) => switch (state) {
    ImageComponentState value => value.mediaPath,
    VideoComponentState value => value.mediaPath,
    AudioComponentState value => value.mediaPath,
    _ => null,
  };

  static void _setMediaPath(Object state, String? path) {
    if (state is ImageComponentState) {
      state.mediaPath = path;
    } else if (state is VideoComponentState) {
      state.mediaPath = path;
    } else if (state is AudioComponentState) {
      state.mediaPath = path;
    }
  }

  static Iterable<NavigationNode> _pageNodes(NavigationNode node) sync* {
    if (node.isPage) {
      yield node;
    }
    for (final child in node.children) {
      yield* _pageNodes(child);
    }
  }

  static Iterable<NavigationNode> _assetFolderNodes(NavigationNode node) sync* {
    if (node.isAssetsFolder) {
      yield node;
    }
    for (final child in node.children) {
      yield* _assetFolderNodes(child);
    }
  }

  static void _pairNavigationNodes(
    NavigationNode source,
    NavigationNode copied,
    Map<String, String> pageIds,
    Map<String, dynamic> assetFiles,
    String packagePath,
    bool useAbsoluteAssetPaths,
  ) {
    if (source.pageId != null && copied.pageId != null) {
      pageIds[source.pageId!] = copied.pageId!;
    }
    if (source.isAssetsFolder && copied.isAssetsFolder) {
      for (var index = 0; index < copied.assets.length; index++) {
        final asset = copied.assets[index];
        final sourceAsset = source.assets[index];
        final key = '${source.folderId}/${sourceAsset.id}';
        final encodedAsset = assetFiles[key];
        if (encodedAsset is String) {
          final relativePath =
              'assets/${copied.folderId}/${asset.id}${_assetExtension(asset.name)}';
          final targetPath = '$packagePath/$relativePath';
          final targetFile = File(targetPath);
          targetFile.parent.createSync(recursive: true);
          targetFile.writeAsBytesSync(base64Decode(encodedAsset));
          copied.assets[index] = BookletAsset(
            id: asset.id,
            name: asset.name,
            path: useAbsoluteAssetPaths ? targetPath : relativePath,
          );
        }
      }
    }
    for (var index = 0; index < source.children.length; index++) {
      _pairNavigationNodes(
        source.children[index],
        copied.children[index],
        pageIds,
        assetFiles,
        packagePath,
        useAbsoluteAssetPaths,
      );
    }
  }

  static NavigationNode? _findPageNode(NavigationNode node, String pageId) {
    if (node.pageId == pageId) {
      return node;
    }
    for (final child in node.children) {
      final result = _findPageNode(child, pageId);
      if (result != null) {
        return result;
      }
    }
    return null;
  }

  static Future<PageContent> loadPage(
    String packagePath,
    String pageId,
    PageSettingsController theme,
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

        final storedId = componentJson['id'];
        final id = storedId is String && storedId.isNotEmpty
            ? storedId
            : const Uuid().v4();
        final component = InbuiltComponents.prepareCompoent(id, type);
        final componentState = component.state;
        if (componentState is ListItemComponentState) {
          final nestingLevel = componentJson['nestingLevel'];
          if (nestingLevel is num) {
            componentState.nestingLevel = nestingLevel.toInt();
          }
          if (componentState is BulletedListComponentState) {
            componentState.symbol = componentJson['symbol'] as String? ?? '•';
          } else if (componentState is NumberedListComponentState) {
            componentState.numberStyle =
                componentJson['numberStyle'] as String? ?? '1.';
          } else if (componentState is ChecklistComponentState) {
            componentState.isChecked = componentJson['checked'] as bool? ?? false;
          }
        }
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
        } else if (componentState is VideoComponentState) {
          componentState.mediaPath = _resolvePackageMediaPath(
            packagePath,
            componentJson['mediaPath'] as String?,
          );
        } else if (componentState is AudioComponentState) {
          componentState.mediaPath = _resolvePackageMediaPath(
            packagePath,
            componentJson['mediaPath'] as String?,
          );
        } else if (componentState is CodeBlockComponentState) {
          componentState.controller.text =
              (componentJson['code'] as String?) ?? '';
          componentState.setLanguage(
            (componentJson['language'] as String?) ?? 'plaintext',
          );
        } else if (componentState is MathComponentState) {
          componentState.controller.text =
              (componentJson['formula'] as String?) ?? '';
        } else if (componentState is EmbedComponentState) {
          componentState.setContent(
            (componentJson['content'] as String?) ?? '',
          );
        } else if (componentState is LinkComponentState) {
          componentState.setValues(
            url: (componentJson['url'] as String?) ?? '',
            title: componentJson['title'] as String?,
          );
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
        components.add(ComponentBox(component: component, delta: delta));
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
    String? selectedAssetFolderId,
    String? sourcePackagePath,
  }) async {
    await _ensurePackageDirectories(packagePath);
    await _persistNavigationAssets(
      packagePath,
      groups,
      sourcePackagePath: sourcePackagePath,
    );
    final json = const JsonEncoder.withIndent('  ').convert({
      'version': 1,
      'selectedPageId': selectedPageId,
      'selectedAssetFolderId': selectedAssetFolderId,
      'navigation': groups
          .map((group) => group.toJson(embedAssets: false))
          .toList(),
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
          if (richText.styles.isNotEmpty)
            'styles': richText.styles.map((s) => s.toJson()).toList(),
          ..._listStateJson(state),
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
          if (quote.styles.isNotEmpty)
            'styles': quote.styles.map((s) => s.toJson()).toList(),
          'author': author.content,
          if (author.styles.isNotEmpty)
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
      if (state is VideoComponentState) {
        componentJson.add({
          'id': componentBox.component.id,
          'type': componentBox.component.def.key,
          'mediaPath': await _persistVideoAsset(packagePath, state),
        });
        continue;
      }
      if (state is AudioComponentState) {
        componentJson.add({
          'id': componentBox.component.id,
          'type': componentBox.component.def.key,
          'mediaPath': await _persistAudioAsset(packagePath, state),
        });
        continue;
      }
      if (state is CodeBlockComponentState) {
        componentJson.add({
          'id': componentBox.component.id,
          'type': componentBox.component.def.key,
          'code': state.controller.text,
          'language': state.languageId,
        });
        continue;
      }
      if (state is MathComponentState) {
        componentJson.add({
          'id': componentBox.component.id,
          'type': componentBox.component.def.key,
          'formula': state.controller.text,
        });
        continue;
      }
      if (state is EmbedComponentState) {
        componentJson.add({
          'id': componentBox.component.id,
          'type': componentBox.component.def.key,
          'content': state.content,
        });
        continue;
      }
      if (state is LinkComponentState) {
        componentJson.add({
          'id': componentBox.component.id,
          'type': componentBox.component.def.key,
          'url': state.url,
          'title': state.title,
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

  static Map<String, dynamic> _listStateJson(ComponentState state) {
    if (state is BulletedListComponentState) {
      return {'symbol': state.symbol, 'nestingLevel': state.nestingLevel};
    }
    if (state is NumberedListComponentState) {
      return {
        'numberStyle': state.numberStyle,
        'nestingLevel': state.nestingLevel,
      };
    }
    if (state is ChecklistComponentState) {
      return {
        'checked': state.isChecked,
        'nestingLevel': state.nestingLevel,
      };
    }
    return const {};
  }

  static String _normalizePackagePath(String path) =>
      path.endsWith('.$_extension') ? path : '$path.$_extension';

  static Future<void> _persistNavigationAssets(
    String packagePath,
    List<NavigationNode> nodes, {
    String? sourcePackagePath,
  }) async {
    for (final node in nodes) {
      if (node.isAssetsFolder) {
        final folderId = node.folderId ?? '';
        final assetDirectory = Directory('$packagePath/assets/$folderId');
        await assetDirectory.create(recursive: true);
        for (var index = 0; index < node.assets.length; index++) {
          final asset = node.assets[index];
          final targetPath =
              '${assetDirectory.path}/${asset.id}${_assetExtension(asset.name)}';
          final targetFile = File(targetPath);
          final storedPath = asset.path;
          final isAbsolute = File(storedPath).isAbsolute;
          final sourcePath = isAbsolute
              ? storedPath
              : '${sourcePackagePath ?? packagePath}/$storedPath';
          final sourceFile = File(sourcePath);
          if (await sourceFile.exists() &&
              sourceFile.absolute.path != targetFile.absolute.path) {
            await sourceFile.copy(targetPath);
          }
          if (await targetFile.exists()) {
            node.assets[index] = BookletAsset(
              id: asset.id,
              name: asset.name,
              path: _toPackageMediaPath(packagePath, targetPath),
            );
          }
        }
        await File('${assetDirectory.path}/$_assetIndexName').writeAsString(
          jsonEncode([
            for (final asset in node.assets)
              {'id': asset.id, 'name': asset.name},
          ]),
        );
      }
      await _persistNavigationAssets(
        packagePath,
        node.children,
        sourcePackagePath: sourcePackagePath,
      );
    }
  }

  static String _assetExtension(String name) {
    final dotIndex = name.lastIndexOf('.');
    return dotIndex < 0 ? '' : name.substring(dotIndex);
  }

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

    final mediaDirectory = Directory('$packagePath/$_mediaDirectory');
    await mediaDirectory.create(recursive: true);
    final normalizedSourcePath = sourceFile.absolute.path.replaceAll('\\', '/');
    final normalizedMediaPath = mediaDirectory.absolute.path.replaceAll(
      '\\',
      '/',
    );
    if (normalizedSourcePath.startsWith('$normalizedMediaPath/')) {
      return {
        'mediaPath': _toPackageMediaPath(packagePath, sourcePath),
        'imageSize': state.imageSize ?? 'medium',
        'width': state.width,
        'height': state.height,
      };
    }

    final extension = _mediaExtension(sourcePath) ?? 'png';
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

  static Future<String?> _persistVideoAsset(
    String packagePath,
    VideoComponentState state,
  ) async {
    final sourcePath = state.mediaPath;
    if (sourcePath == null || sourcePath.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(sourcePath);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return sourcePath;
    }

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      return _toPackageMediaPath(
        packagePath,
        _resolvePackageMediaPath(packagePath, sourcePath)!,
      );
    }

    final mediaDirectory = Directory('$packagePath/$_mediaDirectory');
    await mediaDirectory.create(recursive: true);
    final normalizedSourcePath = sourceFile.absolute.path.replaceAll('\\', '/');
    final normalizedMediaPath = mediaDirectory.absolute.path.replaceAll(
      '\\',
      '/',
    );
    if (normalizedSourcePath.startsWith('$normalizedMediaPath/')) {
      return _toPackageMediaPath(packagePath, sourcePath);
    }

    final extension = _mediaExtension(sourcePath) ?? 'mp4';
    final targetFile = File(
      '${mediaDirectory.path}/${const Uuid().v4()}.$extension',
    );
    await sourceFile.copy(targetFile.path);
    state.mediaPath = targetFile.path;
    return _toPackageMediaPath(packagePath, targetFile.path);
  }

  static Future<String?> _persistAudioAsset(
    String packagePath,
    AudioComponentState state,
  ) async {
    final sourcePath = state.mediaPath;
    if (sourcePath == null || sourcePath.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(sourcePath);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return sourcePath;
    }

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      return _toPackageMediaPath(
        packagePath,
        _resolvePackageMediaPath(packagePath, sourcePath)!,
      );
    }

    final mediaDirectory = Directory('$packagePath/$_mediaDirectory');
    await mediaDirectory.create(recursive: true);
    final normalizedSourcePath = sourceFile.absolute.path.replaceAll('\\', '/');
    final normalizedMediaPath = mediaDirectory.absolute.path.replaceAll(
      '\\',
      '/',
    );
    if (normalizedSourcePath.startsWith('$normalizedMediaPath/')) {
      return _toPackageMediaPath(packagePath, sourcePath);
    }

    final extension = _mediaExtension(sourcePath) ?? 'mp3';
    final targetFile = File(
      '${mediaDirectory.path}/${const Uuid().v4()}.$extension',
    );
    await sourceFile.copy(targetFile.path);
    state.mediaPath = targetFile.path;
    return _toPackageMediaPath(packagePath, targetFile.path);
  }

  static String? _resolvePackageMediaPath(
    String packagePath,
    String? mediaPath,
  ) {
    if (mediaPath == null || mediaPath.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(mediaPath);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return mediaPath;
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

  static String? _mediaExtension(String path) {
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
    await Directory('$packagePath/assets').create(recursive: true);
    await Directory('$packagePath/custom_components').create(recursive: true);
    await Directory('$packagePath/metadata').create(recursive: true);
  }
}
