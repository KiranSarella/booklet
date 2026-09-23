import 'dart:convert';
import 'dart:io';

import 'package:booklet/business/page_content.dart';
import 'package:booklet/ui/components/inbuilt_component_objects.dart';
import 'package:booklet/ui/components/inbuilt_components.dart';
import 'package:booklet/ui/editor_themes/editor_themes.dart';
import 'package:booklet/ui/navigation/navigation_node.dart';
import 'package:file_selector/file_selector.dart';
import 'package:booklet/ui/components/component_box.dart';

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
        final delta = componentJson['delta'];
        if (type == null || delta is! List) {
          continue;
        }
        components.add(
          ComponentBox(component: InbuiltComponents.prepareCompoent("id", type),
          delta: delta 
        )

          // ComponentBox(
          //   componentInfo: ComponentInfo(
          //     renderer: Component.fromType(type, theme),
          //   ),
          //   delta: delta,
          // ),
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
    final json = const JsonEncoder.withIndent('  ').convert({
      'id': page.id,
      'title': page.title,
      'components': [
        for (final componentBox in page.components)
          {
            'type': componentBox.component.def.name,
            'delta': componentBox.componentState.controller.document.toDelta().toJson(),
          },
      ],
    });
    await File('$packagePath/$_pagesDirectory/${page.id}.json')
        .writeAsString(json);
  }

  static String _normalizePackagePath(String path) =>
      path.endsWith('.$_extension') ? path : '$path.$_extension';

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
    await Directory('$packagePath/media').create(recursive: true);
    await Directory('$packagePath/custom_components').create(recursive: true);
    await Directory('$packagePath/metadata').create(recursive: true);
  }
}
