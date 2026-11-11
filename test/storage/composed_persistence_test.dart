import 'package:booklet/storage/booklet_archive.dart';
import 'package:booklet/application/editor_controller.dart';
import 'package:booklet/business/components_business/component_def.dart';
import 'package:booklet/ui/components/inbuilt_components/inbuilt_components.dart';
import 'package:booklet/ui/sidebar/pages_navigation/navigation_node.dart';
import 'package:booklet/ui/sidebar/pages_navigation/pages_navigation_vm.dart';

import 'dart:convert';
import 'dart:io';

import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/business/page_content.dart';
import 'package:booklet/storage/booklet_file.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_snapshot.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/components/composed/composed_component.dart';
import 'package:booklet/ui/components/composed/composition.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CompositionLibrary.templates.clear();
    CompositionLibrary.documentTemplates.clear();
  });
  test('shared archive opens without local templates and preserves conflicting local versions', () async {
    final directory = await Directory.systemTemp.createTemp(
      'shared_compositions',
    );
    addTearDown(() => directory.delete(recursive: true));
    final document = DocumentSettingsController();
    final theme = PageSettingsController(document);
    addTearDown(theme.dispose);
    addTearDown(document.dispose);
    final template = CompositionTemplate(
      'shared',
      'Shared callout',
      CompositionNode(
        'column',
        horizontalPadding: 24,
        focusBar: true,
        children: [CompositionNode('text')],
      ),
    );
    await CompositionLibrary.save(template);
    final component = ComposedComponent(
      'shared-instance',
      CompositionTemplate.fromJson(template.toJson()),
    );
    (component.state.leaves.values.single.component.state as TextComponentState)
        .controller
        .document
        .insert(0, 'Shared content');
    final page = PageContent(
      id: 'shared-page',
      title: 'Shared page',
      components: [ComponentBox(component: component)],
    );
    final package = '${directory.path}/package';
    await BookletFile.savePage(package, page);
    await BookletFile.saveManifest(
      packagePath: package,
      groups: [
        NavigationNode.group(title: 'Group')
          ..children.add(
            NavigationNode.page(title: page.title, pageId: page.id),
          ),
      ],
      selectedPageId: page.id,
    );
    expect(await Directory('$package/custom_components').list().length, 1);
    final pageJson = await File('$package/pages/${page.id}.json')
        .readAsString();
    expect(pageJson, isNot(contains('horizontalPadding')));
    final archive = '${directory.path}/shared.booklet';
    await BookletArchive.write(package, archive);
    page.dispose();
    SharedPreferences.setMockInitialValues({});
    CompositionLibrary.templates.clear();
    final opened = await BookletArchive.open(archive);
    addTearDown(() => opened.workspace.delete(recursive: true));
    final received = await BookletFile.loadPage(
      opened.packagePath,
      'shared-page',
      theme,
    );
    final state = received.components.single.component.state as ComposedState;
    expect(state.template.root.horizontalPadding, 24);
    expect(state.template.root.focusBar, isTrue);
    expect(state.leaves.values.single.component.output, 'Shared content\n');
    expect(CompositionLibrary.templates, isEmpty);
    expect(CompositionLibrary.documentTemplates, isNotEmpty);
    received.dispose();
    final conflicting = CompositionTemplate(
      'shared',
      'Unrelated local component',
      CompositionNode('column', children: [CompositionNode('text')]),
    );
    conflicting.root.horizontalPadding = 60;
    await CompositionLibrary.save(conflicting);
    final conflictPage = await BookletFile.loadPage(
      opened.packagePath,
      'shared-page',
      theme,
    );
    final imported =
        conflictPage.components.single.component.state as ComposedState;
    expect(CompositionLibrary.find('shared')!.root.horizontalPadding, 60);
    expect(imported.template.id, isNot('shared'));
    expect(imported.template.root.horizontalPadding, 24);
    expect(imported.leaves.values.single.component.output, 'Shared content\n');
    final importedId = imported.template.id;
    conflictPage.dispose();
    final again = await BookletFile.loadPage(
      opened.packagePath,
      'shared-page',
      theme,
    );
    expect(
      (again.components.single.component.state as ComposedState).template.id,
      importedId,
    );
    expect(CompositionLibrary.templates.length, 1);
    await BookletFile.savePage(opened.packagePath, again);
    again.dispose();
    SharedPreferences.setMockInitialValues({});
    CompositionLibrary.templates.clear();
    final resaved = await BookletFile.loadPage(
      opened.packagePath,
      'shared-page',
      theme,
    );
    expect(
      (resaved.components.single.component.state as ComposedState)
          .leaves
          .values
          .single
          .component
          .output,
      'Shared content\n',
    );
    resaved.dispose();
  });
  test('editor autosaves nested composed text content', () async {
    final directory = await Directory.systemTemp.createTemp(
      'composed_autosave',
    );
    final document = DocumentSettingsController();
    final theme = PageSettingsController(document);
    final template = CompositionTemplate(
      'autosave',
      'Autosave',
      CompositionNode('column', children: [CompositionNode('text')]),
    );
    await CompositionLibrary.save(template);
    final initial = PageContent(
      id: 'page',
      title: 'Page',
      components: [
        ComponentBox(
          component: ComposedComponent(
            'instance',
            CompositionTemplate.fromJson(template.toJson()),
          ),
        ),
      ],
    );
    await BookletFile.savePage(directory.path, initial);
    await BookletFile.saveManifest(
      packagePath: directory.path,
      groups: [
        NavigationNode.group(title: 'Group')
          ..children.add(NavigationNode.page(title: 'Page', pageId: 'page')),
      ],
      selectedPageId: 'page',
    );
    initial.dispose();
    final editor = EditorController(
      theme,
      document,
      autoSaveDelay: const Duration(milliseconds: 20),
    );
    try {
      await editor.openBookletAtPath(directory.path);
      final state =
          editor.selectedPage!.components.single.component.state
              as ComposedState;
      final text =
          state.leaves.values.single.component.state as TextComponentState;
      text.controller.replaceText(
        0,
        0,
        'Autosaved composed content',
        text.controller.selection,
      );
      // Await observable saved content rather than depending on disk timing.
      var saved = '';
      for (var attempt = 0; attempt < 30; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        saved = await File('${directory.path}/pages/page.json').readAsString();
        if (saved.contains('Autosaved composed content')) break;
      }
      expect(saved, contains('Autosaved composed content'));
      expect(saved, isNot(contains('horizontalPadding')));
      expect(editor.autoSaveError, isNull);
      final personal = await CompositionLibrary.addToPersonal(state.template);
      final edited = CompositionTemplate.fromJson(personal.toJson());
      edited.root.horizontalPadding = 31;
      edited.root.spacing = 23;
      await CompositionLibrary.save(edited);
      expect(state.template.root.horizontalPadding, 31);
      await editor.flushAutoSave();
      final filename = base64Url
          .encode(utf8.encode(state.template.id))
          .replaceAll('=', '');
      final structure = jsonDecode(
        await File('${directory.path}/custom_components/$filename.json')
            .readAsString(),
      ) as Map;
      expect((structure['root'] as Map)['horizontalPadding'], 31);
      expect((structure['root'] as Map)['spacing'], 23);
      expect(structure['sourcePersonalId'], personal.id);
      expect(
        state.leaves.values.single.component.output,
        'Autosaved composed content\n',
      );
      expect(editor.autoSaveError, isNull);
    } finally {
      editor.dispose();
      theme.dispose();
      document.dispose();
      await directory.delete(recursive: true);
    }
  });
  test('page saves composed content and reopens with current structure and portable media', () async {
    final directory = await Directory.systemTemp.createTemp(
      'composed_persistence',
    );
    addTearDown(() => directory.delete(recursive: true));
    final document = DocumentSettingsController();
    final theme = PageSettingsController(document);
    addTearDown(theme.dispose);
    addTearDown(document.dispose);
    final textNode = CompositionNode('text');
    final imageNode = CompositionNode('image');
    final template = CompositionTemplate(
      'text-image',
      'Text + image',
      CompositionNode(
        'row',
        horizontalPadding: 24,
        children: [textNode, imageNode],
      ),
    );
    await CompositionLibrary.save(template);
    final component = ComposedComponent(
      'instance',
      CompositionTemplate.fromJson(template.toJson()),
    );
    final text =
        component.state.leaves.values.first.component.state
            as TextComponentState;
    text.controller.document.insert(0, 'Persist this text');
    final image =
        component.state.leaves.values.last.component.state
            as ImageComponentState;
    final source = File('${directory.path}/source.png');
    await source.writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jO1sAAAAASUVORK5CYII=',
      ),
    );
    image.mediaPath = source.path;
    image.caption = 'Persist this caption';
    final page = PageContent(
      id: 'page',
      title: 'Composed page',
      components: [ComponentBox(component: component)],
    );
    final package = '${directory.path}/original';
    await BookletFile.savePage(package, page);
    expect(await File(image.mediaPath!).exists(), isTrue);
    final saved = jsonDecode(
      await File('$package/pages/page.json').readAsString(),
    ) as Map;
    final record = (saved['components'] as List).single as Map;
    expect(record['type'], 'composed:text-image');
    expect(record['kind'], 'composed');
    expect(component.def.kind, ComponentKind.composed);
    expect(
      InbuiltComponents.getComponentMenuItems().every(
        (def) => def.kind == ComponentKind.inbuilt,
      ),
      isTrue,
    );
    expect(record['templateId'], 'text-image');
    expect(record.containsKey('template'), isFalse);
    expect(jsonEncode(record), isNot(contains('horizontalPadding')));
    expect(jsonEncode(record), isNot(contains('spacing')));
    expect(
      (record['children'] as Map).keys,
      containsAll([textNode.id, imageNode.id]),
    );
    expect(jsonEncode(record), contains('media/'));
    expect(jsonEncode(record), isNot(contains(directory.path)));
    page.dispose();
    final moved = '${directory.path}/moved';
    await Directory(package).rename(moved);
    SharedPreferences.setMockInitialValues({});
    CompositionLibrary.templates.clear();
    final loaded = await BookletFile.loadPage(moved, 'page', theme);
    final restored = loaded.components.single.component as ComposedComponent;
    expect(
      restored.state.leaves.values.first.component.output,
      'Persist this text\n',
    );
    final restoredImage =
        restored.state.leaves.values.last.component.state
            as ImageComponentState;
    expect(restoredImage.caption, 'Persist this caption');
    expect(restoredImage.mediaPath, startsWith(moved));
    expect(await File(restoredImage.mediaPath!).exists(), isTrue);
    final originalPath = restoredImage.mediaPath;
    final node = NavigationNode.page(title: loaded.title, pageId: loaded.id);
    final bundle = await BookletFile.exportNavigationSubtree(
      packagePath: moved,
      node: node,
      loadedPages: [loaded],
      theme: theme,
    );
    expect(restoredImage.mediaPath, originalPath);
    expect(await File(restoredImage.mediaPath!).exists(), isTrue);
    final navigation = PagesNavigationVM()..addGroup(title: 'Copy');
    final copiedNode = navigation.pasteNode(node)!;
    final copyPath = '${directory.path}/copy';
    SharedPreferences.setMockInitialValues({});
    CompositionLibrary.templates.clear();
    await BookletFile.importNavigationSubtree(
      packagePath: copyPath,
      sourceNode: node,
      copiedNode: copiedNode,
      bundle: bundle,
      useAbsoluteAssetPaths: false,
    );
    final copiedPage = await BookletFile.loadPage(
      copyPath,
      copiedNode.pageId!,
      theme,
    );
    final copiedState =
        copiedPage.components.single.component.state as ComposedState;
    final copiedImage =
        copiedState.leaves.values.last.component.state as ImageComponentState;
    expect(copiedImage.mediaPath, startsWith(copyPath));
    expect(await File(copiedImage.mediaPath!).exists(), isTrue);
    copiedPage.dispose();
    final personal = await CompositionLibrary.addToPersonal(
      restored.state.template,
    );
    final updated = CompositionTemplate.fromJson(personal.toJson());
    updated.root.horizontalPadding = 40;
    updated.root.children = updated.root.children.reversed.toList();
    await CompositionLibrary.save(updated);
    expect(restored.state.template.root.horizontalPadding, 40);
    expect(restored.state.leaves.keys.first.kind, 'image');
    expect(
      restored.state.leaves.values.last.component.output,
      'Persist this text\n',
    );
    await BookletFile.savePage(moved, loaded);
    loaded.dispose();
    CompositionLibrary.templates.clear();
    final reopened = await BookletFile.loadPage(moved, 'page', theme);
    final finalState =
        reopened.components.single.component.state as ComposedState;
    expect(finalState.template.root.horizontalPadding, 40);
    expect(
      finalState.leaves.values.last.component.output,
      'Persist this text\n',
    );
    reopened.dispose();
  });
  test(
    'unavailable structure retains content until the template is restored',
    () async {
      final template = CompositionTemplate(
        'missing',
        'Restorable',
        CompositionNode('column', children: [CompositionNode('text')]),
      );
      await CompositionLibrary.save(template);
      final source = ComposedComponent(
        'source',
        CompositionTemplate.fromJson(template.toJson()),
      );
      (source.state.leaves.values.single.component.state as TextComponentState)
          .controller
          .document
          .insert(0, 'Keep me');
      final snapshot = ComponentSnapshot.capture(
        ComponentBox(component: source),
      );
      source.dispose();
      CompositionLibrary.templates.clear();
      final missing = snapshot.instantiate();
      expect(
        jsonEncode((missing.component.state as ComposedState).toJson()),
        contains('Keep me'),
      );
      await CompositionLibrary.load();
      final restored = missing.component.state as ComposedState;
      expect(restored.leaves.values.single.component.output, 'Keep me\n');
      missing.dispose();
    },
  );
  test(
    'legacy structure node IDs are migrated once and remain stable on reload',
    () async {
      SharedPreferences.setMockInitialValues({
        CompositionLibrary.storageKey: jsonEncode([
          {
            'id': 'legacy',
            'name': 'Legacy',
            'root': {
              'kind': 'column',
              'children': [
                {'kind': 'text'},
              ],
            },
          },
        ]),
      });
      await CompositionLibrary.load();
      final first = CompositionLibrary.templates.single.root.children.single.id;
      await CompositionLibrary.load();
      expect(
        CompositionLibrary.templates.single.root.children.single.id,
        first,
      );
    },
  );
}
