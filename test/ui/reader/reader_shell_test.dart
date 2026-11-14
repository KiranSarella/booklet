import 'dart:io';

import 'package:booklet/application/app.dart';
import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/business/page_content.dart';
import 'package:booklet/storage/booklet_file.dart';
import 'package:booklet/ui/reader/reader_shell.dart';
import 'package:booklet/ui/detail/editor/page_view/page_view.dart' as editor;
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/inbuilt_components/inbuilt_components.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:booklet/ui/sidebar/pages_navigation/navigation_node.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('reader cannot be unlocked by preferences or mode changes', () async {
    SharedPreferences.setMockInitialValues({'document.editMode': 'edit'});
    final settings = DocumentSettingsController(forceReadOnly: true);
    addTearDown(settings.dispose);
    expect(settings.isReadOnly, isTrue);
    await settings.load();
    settings.updateEditMode(DocumentEditMode.edit);
    expect(settings.editMode, DocumentEditMode.readOnly);
    final page = PageSettingsController(settings);
    final app = App(page, settings);
    expect(await app.editorController.saveBooklet(), isFalse);
    expect(await app.editorController.saveBookletAs(), isFalse);
    // App owns settings; avoid disposing settings twice.
    app.editorController.dispose();
    page.dispose();
  });

  testWidgets(
    'missing recent documents leave the reader on startup with recovery guidance',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'booklets.recents.v1': ['/missing/Study.booklet'],
      });
      final settings = DocumentSettingsController(forceReadOnly: true);
      final app = App(PageSettingsController(settings), settings);
      await tester.pumpWidget(
        MaterialApp(
          home: ReaderShell(application: app, onOpen: () async {}),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Study.booklet'));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(app.screen, AppScreen.startup);
      expect(
        find.textContaining('Use Open booklet to select it again.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
    },
  );

  for (final size in [
    const Size(400, 800),
    const Size(800, 1100),
    const Size(1200, 800),
  ]) {
    testWidgets(
      'reader opens and navigates without editing controls at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final settings = DocumentSettingsController(forceReadOnly: true);
        final app = App(PageSettingsController(settings), settings);
        final temp = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('reader_test'),
        ))!;
        final package = '${temp.path}/example.booklet';
        final first = PageContent(
          id: 'one',
          title: 'First page',
          components: [
            ComponentBox(
              component: InbuiltComponents.prepareCompoent(
                'reader-text',
                'text',
              ),
              delta: [
                {'insert': 'Tablet reading example.\n'},
              ],
            ),
          ],
        );
        final second = PageContent(
          id: 'two',
          title: 'Second page',
          components: [],
        );
        await tester.runAsync(() async {
          await BookletFile.savePage(package, first);
          await BookletFile.savePage(package, second);
          first.dispose();
          second.dispose();
          await BookletFile.saveManifest(
            packagePath: package,
            groups: [
              NavigationNode.group(title: 'Chapter')
                ..children.addAll([
                  NavigationNode.page(title: 'First page', pageId: 'one'),
                  NavigationNode.page(title: 'Second page', pageId: 'two'),
                ]),
            ],
            selectedPageId: 'one',
          );
        });
        final before = await tester.runAsync(
          () => File('$package/pages/one.json').stat(),
        );
        var opens = 0;
        Future<bool>? opening;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [FlutterQuillLocalizations.delegate],
            home: ReaderShell(
              application: app,
              onOpen: () async {
                opens++;
                opening = app.openBookletAtPath(package);
                await opening;
              },
            ),
          ),
        );
        expect(
          find.widgetWithText(FilledButton, 'Open booklet'),
          findsOneWidget,
        );
        expect(find.text('Create booklet'), findsNothing);
        await tester.runAsync(() async {
          await tester.tap(find.widgetWithText(FilledButton, 'Open booklet'));
          await opening;
        });
        await tester.pumpAndSettle();
        expect(opens, 1);
        app.editorTheme.updatePageWidth(PageWidth.wide);
        await tester.pumpAndSettle();
        final pageSurface = find
            .descendant(
              of: find.byType(editor.PageView),
              matching: find.byType(Container),
            )
            .first;
        expect(tester.getTopLeft(pageSurface).dx, 0);
        expect(tester.getSize(pageSurface).width, size.width);
        expect(
          tester.widget<Container>(pageSurface).padding,
          EdgeInsets.all(size.width < 600 ? 12 : 32),
        );

        expect(find.byTooltip('Appearance'), findsOneWidget);
        expect(find.byTooltip('Show minimap'), findsNothing);
        expect(
          find.textContaining('Tablet reading example.', findRichText: true),
          findsWidgets,
        );
        await tester.tap(find.text('Find in page'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'Tablet');
        await tester.pumpAndSettle();
        expect(find.text('1 / 1'), findsOneWidget);
        await tester.tap(find.byTooltip('Close page search'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Pages'));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await tester.tap(find.text('Second page').last);
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        expect(app.editorController.viewModel.selectedPageId, 'two');
        final after = await tester.runAsync(
          () => File('$package/pages/one.json').stat(),
        );
        expect(after!.modified, before!.modified);
        await tester.tap(find.byTooltip('Appearance'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('App appearance'), findsOneWidget);
        final appModes = find.byType(SegmentedButton<DocumentAppearanceMode>);
        await tester.tap(
          find.descendant(of: appModes, matching: find.text('Dark')),
        );
        await tester.pumpAndSettle();
        expect(
          app.documentSettingsController.appearanceMode,
          DocumentAppearanceMode.dark,
        );

        expect(find.text('Page width'), findsOneWidget);
        expect(find.text('Normal'), findsOneWidget);
        expect(find.text('Wide'), findsOneWidget);
        expect(find.text('Columns'), findsNothing);
        expect(find.text('Page appearance'), findsOneWidget);
        expect(find.text('Body font'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        app.dispose();
        await tester.runAsync(() => temp.delete(recursive: true));
      },
    );
  }
}
