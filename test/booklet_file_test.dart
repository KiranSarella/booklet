import 'dart:convert';
import 'dart:io';

import 'package:booklet/business/booklet_asset.dart';
import 'package:booklet/business/page_content.dart';
import 'package:booklet/storage/booklet_file.dart';
import 'package:booklet/ui/components/audio_component.dart';
import 'package:booklet/ui/components/code_block_component.dart';
import 'package:booklet/ui/components/math_component.dart';
import 'package:booklet/ui/components/link_component.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/components/embed_component.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/image_component.dart';
import 'package:booklet/ui/components/inbuilt_components.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/ui/navigation/navigation_node.dart';
import 'package:booklet/ui/navigation/navigation_panel_vm.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test(
    'copies nested navigation pages and resources between booklets',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'booklet_navigation_copy_test',
      );
      final sourcePath = '${tempDir.path}/source';
      final targetPath = '${tempDir.path}/target';
      final imageFile = File('${tempDir.path}/source-image.png');
      await imageFile.writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10]);
      final assetFile = File(
        '$sourcePath/assets/folder-original/asset-original.pdf',
      );
      await assetFile.parent.create(recursive: true);
      await assetFile.writeAsBytes([1, 2, 3, 4]);

      final page = PageContent(
        id: 'page-original',
        title: 'Copied page',
        components: [
          ComponentBox(
            component: ImageComponent(
              id: 'image-original',
              mediaPath: imageFile.path,
            ),
          ),
        ],
      );
      await BookletFile.savePage(sourcePath, page);
      final sourceGroup = NavigationNode.group(title: 'Copied group');
      final sourcePage = NavigationNode.page(
        title: page.title,
        pageId: page.id,
      );
      final sourceFolder = NavigationNode.assetsFolder(
        title: 'References',
        folderId: 'folder-original',
      );
      sourceFolder.assets.add(
        const BookletAsset(
          id: 'asset-original',
          name: 'paper.pdf',
          path: 'assets/folder-original/asset-original.pdf',
        ),
      );
      sourcePage.children.add(sourceFolder);
      sourceGroup.children.add(sourcePage);

      final bundle = await BookletFile.exportNavigationSubtree(
        packagePath: sourcePath,
        node: sourceGroup,
        loadedPages: [page],
        theme: PageSettingsController(DocumentSettingsController()),
      );
      final bundledNode = NavigationNode.fromJson(
        Map<String, dynamic>.from(bundle['node'] as Map),
      );
      final navigation = NavigationPanelVM()..addGroup(title: 'Existing');
      final copiedGroup = navigation.pasteNode(bundledNode)!;

      await BookletFile.importNavigationSubtree(
        packagePath: targetPath,
        sourceNode: bundledNode,
        copiedNode: copiedGroup,
        bundle: bundle,
        useAbsoluteAssetPaths: false,
      );

      final copiedPage = copiedGroup.children.single;
      final copiedFolder = copiedPage.children.single;
      expect(copiedPage.pageId, isNot(page.id));
      expect(copiedFolder.folderId, isNot(sourceFolder.folderId));
      expect(copiedFolder.assets.single.id, isNot('asset-original'));
      expect(
        File('$targetPath/${copiedFolder.assets.single.path}')
            .readAsBytesSync(),
        [1, 2, 3, 4],
      );

      final loadedCopy = await BookletFile.loadPage(
        targetPath,
        copiedPage.pageId!,
        PageSettingsController(DocumentSettingsController()),
      );
      final copiedImage = loadedCopy.components.single.component;
      expect(File(copiedImage.output as String).existsSync(), isTrue);

      page.dispose();
      loadedCopy.dispose();
      await tempDir.delete(recursive: true);
    },
  );

  group('BookletFile component persistence', () {
    test('persists and restores the same text component ID', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'booklet_component_test',
      );
      final packagePath = '${tempDir.path}/test_booklet';
      const componentId = 'text-component-id';
      final page = PageContent(
        id: 'page-1',
        title: 'Test page',
        components: [
          ComponentBox(
            component: InbuiltComponents.prepareCompoent(componentId, 'text'),
          ),
        ],
      );

      await BookletFile.savePage(packagePath, page);
      final savedPageJson = jsonDecode(
        await File('$packagePath/pages/page-1.json').readAsString(),
      ) as Map<String, dynamic>;
      final savedComponent =
          savedPageJson['components'][0] as Map<String, dynamic>;

      expect(savedComponent['id'], componentId);

      final loadedPage = await BookletFile.loadPage(
        packagePath,
        'page-1',
        PageSettingsController(DocumentSettingsController()),
      );
      expect(loadedPage.components.single.component.id, componentId);

      final loadedAgain = await BookletFile.loadPage(
        packagePath,
        'page-1',
        PageSettingsController(DocumentSettingsController()),
      );
      expect(loadedAgain.components.single.component.id, componentId);

      page.dispose();
      loadedPage.dispose();
      loadedAgain.dispose();
      await tempDir.delete(recursive: true);
    });

    test('persists list symbols, nesting, and checklist state', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'booklet_list_component_test',
      );
      final packagePath = '${tempDir.path}/test_booklet';
      final bullet = InbuiltComponents.prepareCompoent('bullet-1', 'bulleted_list');
      final bulletState = bullet.state as BulletedListComponentState
        ..symbol = '→'
        ..nestingLevel = 2;
      final numbered = InbuiltComponents.prepareCompoent(
        'numbered-1',
        'numbered_list',
      );
      final numberedState = numbered.state as NumberedListComponentState
        ..numberStyle = 'i.'
        ..nestingLevel = 1;
      final checklist = InbuiltComponents.prepareCompoent(
        'checklist-1',
        'checklist',
      );
      final checklistState = checklist.state as ChecklistComponentState
        ..isChecked = true
        ..nestingLevel = 3;
      final page = PageContent(
        id: 'page-1',
        title: 'Test page',
        components: [
          ComponentBox(component: bullet),
          ComponentBox(component: numbered),
          ComponentBox(component: checklist),
        ],
      );

      await BookletFile.savePage(packagePath, page);
      final loadedPage = await BookletFile.loadPage(
        packagePath,
        'page-1',
        PageSettingsController(DocumentSettingsController()),
      );
      final loadedBullet =
          loadedPage.components[0].component.state as BulletedListComponentState;
      final loadedNumbered = loadedPage.components[1].component.state
          as NumberedListComponentState;
      final loadedChecklist = loadedPage.components[2].component.state
          as ChecklistComponentState;

      expect(loadedBullet.symbol, '→');
      expect(loadedBullet.nestingLevel, 2);
      expect(loadedNumbered.numberStyle, 'i.');
      expect(loadedNumbered.nestingLevel, 1);
      expect(loadedChecklist.isChecked, isTrue);
      expect(loadedChecklist.nestingLevel, 3);

      page.dispose();
      loadedPage.dispose();
      await tempDir.delete(recursive: true);
    });
  });

  group('BookletFile image persistence', () {
    test('copies image to media folder and stores size metadata', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'booklet_image_test',
      );
      final packagePath = '${tempDir.path}/test_booklet';
      final sourceFile = File('${tempDir.path}/source.png');
      await sourceFile.writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10]);

      final image = ImageComponent(id: 'image-1', mediaPath: sourceFile.path);
      image.state.width = 640;
      image.state.height = 480;

      final page = PageContent(
        id: 'page-1',
        title: 'Test page',
        components: [ComponentBox(component: image)],
      );

      await BookletFile.savePage(packagePath, page);

      final savedPageJson = jsonDecode(
        await File('$packagePath/pages/page-1.json').readAsString(),
      ) as Map<String, dynamic>;
      final savedImage = savedPageJson['components'][0] as Map<String, dynamic>;

      expect(savedImage['mediaPath'], isNotNull);
      expect(savedImage['mediaPath'], startsWith('media/'));
      expect(savedImage['mediaPath'], endsWith('.png'));
      expect(
        File('$packagePath/${savedImage['mediaPath']}').existsSync(),
        isTrue,
      );
      expect(savedImage['width'], 640);
      expect(savedImage['height'], 480);

      await BookletFile.savePage(packagePath, page);

      final resavedPageJson = jsonDecode(
        await File('$packagePath/pages/page-1.json').readAsString(),
      ) as Map<String, dynamic>;
      final resavedImage =
          resavedPageJson['components'][0] as Map<String, dynamic>;
      final mediaFiles = await Directory('$packagePath/media').list().toList();

      expect(resavedImage['mediaPath'], savedImage['mediaPath']);
      expect(mediaFiles, hasLength(1));

      page.dispose();
      await tempDir.delete(recursive: true);
    });
  });

  group('BookletFile audio persistence', () {
    test('copies audio to media folder and restores its path', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'booklet_audio_test',
      );
      final packagePath = '${tempDir.path}/test_booklet';
      final sourceFile = File('${tempDir.path}/source.mp3');
      await sourceFile.writeAsBytes([1, 2, 3, 4]);

      final audio = AudioComponent(id: 'audio-1', mediaPath: sourceFile.path);
      final page = PageContent(
        id: 'page-1',
        title: 'Test page',
        components: [ComponentBox(component: audio)],
      );

      await BookletFile.savePage(packagePath, page);

      final savedPageJson = jsonDecode(
        await File('$packagePath/pages/page-1.json').readAsString(),
      ) as Map<String, dynamic>;
      final savedAudio = savedPageJson['components'][0] as Map<String, dynamic>;

      expect(savedAudio['type'], 'audio');
      expect(savedAudio['mediaPath'], startsWith('media/'));
      expect(savedAudio['mediaPath'], endsWith('.mp3'));
      expect(
        File('$packagePath/${savedAudio['mediaPath']}').existsSync(),
        isTrue,
      );

      final loadedPage = await BookletFile.loadPage(
        packagePath,
        'page-1',
        PageSettingsController(DocumentSettingsController()),
      );
      final loadedAudio = loadedPage.components.single.component;
      expect(loadedAudio, isA<AudioComponent>());
      expect(loadedAudio.output, audio.state.mediaPath);

      page.dispose();
      loadedPage.dispose();
      await tempDir.delete(recursive: true);
    });
  });

  group('BookletFile code block persistence', () {
    test('persists source code and selected language', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'booklet_code_block_test',
      );
      final packagePath = '${tempDir.path}/test_booklet';
      const code = 'print("hello");\nprint("world");';
      final component = CodeBlockComponent(
        id: 'code-block-1',
        code: code,
        language: 'javascript',
      );
      final page = PageContent(
        id: 'page-1',
        title: 'Test page',
        components: [ComponentBox(component: component)],
      );

      await BookletFile.savePage(packagePath, page);

      final savedPageJson = jsonDecode(
        await File('$packagePath/pages/page-1.json').readAsString(),
      ) as Map<String, dynamic>;
      final savedCodeBlock =
          savedPageJson['components'][0] as Map<String, dynamic>;

      expect(savedCodeBlock['type'], 'code_block');
      expect(savedCodeBlock['code'], code);
      expect(savedCodeBlock['language'], 'javascript');

      final loadedPage = await BookletFile.loadPage(
        packagePath,
        'page-1',
        PageSettingsController(DocumentSettingsController()),
      );
      final loadedCodeBlock = loadedPage.components.single.component;

      expect(loadedCodeBlock, isA<CodeBlockComponent>());
      expect(loadedCodeBlock.output, code);
      expect(
        (loadedCodeBlock.state as CodeBlockComponentState).languageId,
        'javascript',
      );

      page.dispose();
      loadedPage.dispose();
      await tempDir.delete(recursive: true);
    });
  });

  group('BookletFile math persistence', () {
    test('persists and restores the TeX formula', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'booklet_math_test',
      );
      final packagePath = '${tempDir.path}/test_booklet';
      const formula = r'\frac{-b \pm \sqrt{b^2 - 4ac}}{2a}';
      final component = MathComponent(id: 'math-1', formula: formula);
      final page = PageContent(
        id: 'page-1',
        title: 'Test page',
        components: [ComponentBox(component: component)],
      );

      await BookletFile.savePage(packagePath, page);

      final savedPageJson = jsonDecode(
        await File('$packagePath/pages/page-1.json').readAsString(),
      ) as Map<String, dynamic>;
      final savedMath = savedPageJson['components'][0] as Map<String, dynamic>;
      expect(savedMath['type'], 'math');
      expect(savedMath['formula'], formula);

      final loadedPage = await BookletFile.loadPage(
        packagePath,
        'page-1',
        PageSettingsController(DocumentSettingsController()),
      );
      final loadedMath = loadedPage.components.single.component;
      expect(loadedMath, isA<MathComponent>());
      expect(loadedMath.output, formula);

      page.dispose();
      loadedPage.dispose();
      await tempDir.delete(recursive: true);
    });
  });

  group('BookletFile embed persistence', () {
    test('persists and restores pasted embed content', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'booklet_embed_test',
      );
      final packagePath = '${tempDir.path}/test_booklet';
      const content =
          '<iframe src="https://www.youtube.com/embed/dQw4w9WgXcQ" allowfullscreen></iframe>';
      final component = EmbedComponent(id: 'embed-1', content: content);
      final page = PageContent(
        id: 'page-1',
        title: 'Test page',
        components: [ComponentBox(component: component)],
      );

      await BookletFile.savePage(packagePath, page);
      final savedPageJson = jsonDecode(
        await File('$packagePath/pages/page-1.json').readAsString(),
      ) as Map<String, dynamic>;
      final savedEmbed = savedPageJson['components'][0] as Map<String, dynamic>;

      expect(savedEmbed['type'], 'embed');
      expect(savedEmbed['content'], content);

      final loadedPage = await BookletFile.loadPage(
        packagePath,
        'page-1',
        PageSettingsController(DocumentSettingsController()),
      );
      final loadedEmbed = loadedPage.components.single.component;
      expect(loadedEmbed, isA<EmbedComponent>());
      expect(loadedEmbed.output, content);

      page.dispose();
      loadedPage.dispose();
      await tempDir.delete(recursive: true);
    });
  });

  group('BookletFile link persistence', () {
    test('persists and restores URL and optional title separately', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'booklet_link_test',
      );
      final packagePath = '${tempDir.path}/test_booklet';
      final component = LinkComponent(
        id: 'link-1',
        url: 'https://example.com/article',
        title: 'Read the article',
      );
      final page = PageContent(
        id: 'page-1',
        title: 'Test page',
        components: [ComponentBox(component: component)],
      );

      await BookletFile.savePage(packagePath, page);
      final savedPageJson = jsonDecode(
        await File('$packagePath/pages/page-1.json').readAsString(),
      ) as Map<String, dynamic>;
      final savedLink = savedPageJson['components'][0] as Map<String, dynamic>;

      expect(savedLink['type'], 'link');
      expect(savedLink['url'], 'https://example.com/article');
      expect(savedLink['title'], 'Read the article');

      final loadedPage = await BookletFile.loadPage(
        packagePath,
        'page-1',
        PageSettingsController(DocumentSettingsController()),
      );
      final loadedLink = loadedPage.components.single.component;
      expect(loadedLink, isA<LinkComponent>());
      expect(
        (loadedLink.state as LinkComponentState).url,
        'https://example.com/article',
      );
      expect(
        (loadedLink.state as LinkComponentState).title,
        'Read the article',
      );

      page.dispose();
      loadedPage.dispose();
      await tempDir.delete(recursive: true);
    });
  });
}
