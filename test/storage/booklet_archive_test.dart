import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/editor_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/business/page_content.dart';
import 'package:booklet/storage/booklet_archive.dart';
import 'package:booklet/storage/booklet_file.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/components/inbuilt_components/inbuilt_components.dart';
import 'package:booklet/ui/sidebar/pages_navigation/navigation_node.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late DocumentSettingsController settings;
  late PageSettingsController theme;
  late EditorController editor;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temporary = await Directory.systemTemp.createTemp('portable_booklet_test_');
    settings = DocumentSettingsController();
    theme = PageSettingsController(settings);
    editor = EditorController(theme, settings);
  });
  tearDown(() async {
    editor.dispose();
    theme.dispose();
    settings.dispose();
    await temporary.delete(recursive: true);
  });

  test(
    'new documents save as one file and autosave back into that file',
    () async {
      final output = '${temporary.path}/new.booklet';
      expect(await editor.saveBookletToPath(output), isTrue);
      expect(await File(output).exists(), isTrue);
      expect(await Directory(output).exists(), isFalse);
      expect((await File(output).readAsBytes()).take(2), [80, 75]);
      expect(editor.documentFilePath, output);
      final text =
          editor.selectedPage!.components.last.component.state
              as TextComponentState;
      text.controller.replaceText(
        0,
        0,
        'Saved automatically',
        text.controller.selection,
      );
      await editor.flushAutoSave();
      expect(editor.autoSaveError, isNull);
      final opened = await BookletArchive.open(output);
      try {
        final pageId = editor.selectedPage!.id;
        expect(
          await File('${opened.packagePath}/pages/$pageId.json').readAsString(),
          contains('Saved automatically'),
        );
      } finally {
        await opened.workspace.delete(recursive: true);
      }
    },
  );

  Future<String> legacyDocument() async {
    final package = '${temporary.path}/legacy.booklet';
    final nodes = [
      for (final id in ['one', 'two'])
        NavigationNode.page(title: id, pageId: id),
    ];
    for (final node in nodes) {
      final page = PageContent(
        id: node.pageId!,
        title: node.title,
        components: [
          ComponentBox(
            component: InbuiltComponents.prepareCompoent(
              'text-${node.pageId}',
              'text',
            ),
            delta: [
              {'insert': 'Content of ${node.pageId}\n'},
            ],
          ),
        ],
      );
      await BookletFile.savePage(package, page);
      page.dispose();
    }
    await BookletFile.saveManifest(
      packagePath: package,
      groups: nodes,
      selectedPageId: 'one',
    );
    for (final name in [
      'media/picture.png',
      'assets/folder/file.bin',
      '.daily_snapshots/example/extra',
      '.deleted_items/example/extra',
      'metadata/custom.json',
    ]) {
      final file = File('$package/$name');
      await file.parent.create(recursive: true);
      await file.writeAsString('preserved:$name');
    }
    return package;
  }

  test(
    'Save As preserves unloaded pages, media, metadata, snapshots and trash',
    () async {
      final source = await legacyDocument();
      await editor.openBookletAtPath(source);
      final output = '${temporary.path}/portable.booklet';
      await editor.saveBookletToPath(output);
      final opened = await BookletArchive.open(output);
      try {
        for (final name in [
          'pages/two.json',
          'media/picture.png',
          'assets/folder/file.bin',
          '.daily_snapshots/example/extra',
          '.deleted_items/example/extra',
          'metadata/custom.json',
        ]) {
          expect(
            await File('${opened.packagePath}/$name').exists(),
            isTrue,
            reason: name,
          );
        }
      } finally {
        await opened.workspace.delete(recursive: true);
      }
      // Saving As another file must leave the first portable document intact.
      final before = await File(output).readAsBytes();
      final second = '${temporary.path}/second.booklet';
      await editor.saveBookletToPath(second);
      expect(await File(output).readAsBytes(), before);
      await editor.openBookletAtPath(second);
      await editor.selectPage('two');
      expect(editor.selectedPage!.title, 'two');
    },
  );

  test(
    'Save converts a legacy package in place and retains its original backup',
    () async {
      final source = await legacyDocument();
      await editor.openBookletAtPath(source);
      expect(await editor.saveBooklet(), isTrue);
      expect(await File(source).exists(), isTrue);
      final backups = temporary.listSync().whereType<Directory>().where(
        (dir) => dir.path.startsWith('$source.legacy-'),
      );
      expect(backups.length, 1);
      expect(
        await File('${backups.single.path}/content.json').exists(),
        isTrue,
      );
      await editor.openBookletAtPath(source);
      expect(editor.selectedPage!.id, 'one');
    },
  );

  test(
    'portable snapshots survive restore, keep and reopening the single file',
    () async {
      final output = '${temporary.path}/snapshots.booklet';
      await editor.saveBookletToPath(output);
      TextComponentState text() =>
          editor.selectedPage!.components.last.component.state
              as TextComponentState;
      void setText(String value) => text().controller.replaceText(
        0,
        text().controller.document.length - 1,
        value,
        text().controller.selection,
      );
      setText('original');
      await editor.flushAutoSave();
      await editor.createManualBackup();
      expect(editor.snapshotError, isNull);
      final day = editor.dailySnapshots.first.day;
      setText('later edits');
      await editor.flushAutoSave();
      await editor.restoreDailySnapshot(day);
      expect(text().output, 'original\n');
      setText('adopted version');
      await editor.keepRestoredChanges();
      expect(editor.snapshotError, isNull);
      await editor.openBookletAtPath(output);
      expect(text().output, 'adopted version\n');
      expect(editor.dailySnapshots, isNotEmpty);
    },
  );

  test(
    'invalid documents and failed saves do not replace the last saved file',
    () async {
      final output = '${temporary.path}/valid.booklet';
      await editor.saveBookletToPath(output);
      final before = await File(output).readAsBytes();
      final invalid = File('${temporary.path}/invalid.booklet');
      await invalid.writeAsString('not a booklet');
      await expectLater(
        editor.openBookletAtPath(invalid.path),
        throwsA(anything),
      );
      expect(editor.documentFilePath, output);
      await expectLater(
        BookletArchive.write(temporary.path, output),
        throwsA(anything),
      );
      expect(await File(output).readAsBytes(), before);
    },
  );

  test('unsafe archive paths are rejected before extraction', () async {
    final archive = Archive()
      ..addFile(
        ArchiveFile('content.json', 17, utf8.encode('{"navigation":[]}')),
      )
      ..addFile(ArchiveFile('../outside.txt', 4, utf8.encode('bad!')));
    final input = File('${temporary.path}/unsafe.booklet');
    await input.writeAsBytes(ZipEncoder().encode(archive));
    await expectLater(
      BookletArchive.open(input.path),
      throwsA(isA<FormatException>()),
    );
    expect(
      await File('${temporary.parent.path}/outside.txt').exists(),
      isFalse,
    );
  });
}
