import 'dart:io';

import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/editor_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/business/page_content.dart';
import 'package:booklet/storage/booklet_file.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/text_component.dart';
import 'package:booklet/ui/sidebar/pages_navigation/navigation_node.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test(
    'highlights survive page reloads and cleared highlights stay cleared',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'reading_highlights',
      );
      final settings = DocumentSettingsController(forceReadOnly: true);
      final theme = PageSettingsController(settings);
      final editor = EditorController(theme, settings);
      try {
        final group = NavigationNode.group(title: 'Chapter');
        for (final id in ['one', 'two']) {
          group.children.add(NavigationNode.page(title: id, pageId: id));
          final page = PageContent(
            id: id,
            title: id,
            components: [
              ComponentBox(
                component: TextComponent(id: 'text-$id'),
                delta: [
                  {'insert': 'Hello reader\n'},
                ],
              ),
            ],
          );
          await BookletFile.savePage(directory.path, page);
          page.dispose();
        }
        await BookletFile.saveManifest(
          packagePath: directory.path,
          groups: [group],
          selectedPageId: 'one',
        );
        await editor.openBookletAtPath(directory.path);
        TextComponentState current() =>
            editor.selectedPage!.components.single.component.state
                as TextComponentState;
        void select(TextComponentState state) {
          state.controller.readOnly = true;
          state.controller.updateSelection(
            const TextSelection(baseOffset: 0, extentOffset: 5),
            ChangeSource.local,
          );
        }

        final original = current();
        final delta = original.textDelta;
        select(original);
        original.highlightReadingSelection(const Color(0xFFFFF59D));
        await editor.selectPage('two');
        expect(current().readingHighlights.value, isEmpty);
        select(current());
        current().highlightReadingSelection(const Color(0xFF90CAF9));
        // A separate controller simulates closing and reopening the document.
        final reopened = EditorController(theme, settings);
        try {
          await reopened.openBookletAtPath(directory.path);
          final restored =
              reopened.selectedPage!.components.single.component.state
                  as TextComponentState;
          expect(restored.readingHighlights.value, hasLength(5));
          expect(
            restored.readingHighlights.value.values,
            everyElement(const Color(0xFFFFF59D)),
          );
          await reopened.selectPage('two');
          final second =
              reopened.selectedPage!.components.single.component.state
                  as TextComponentState;
          expect(
            second.readingHighlights.value.values,
            everyElement(const Color(0xFF90CAF9)),
          );
        } finally {
          reopened.dispose();
        }
        final highlights = await editor.searchBooklet('', highlightsOnly: true);
        expect(highlights.map((page) => page.pageId), ['one', 'two']);
        expect(
          highlights.every((page) => page.hits.single.query == 'Hello'),
          isTrue,
        );
        expect(
          highlights.every((page) => page.hits.single.matchIndex == 0),
          isTrue,
        );
        expect(editor.selectedPage!.id, 'two');
        await editor.selectPage('one');
        expect(current(), isNot(same(original)));
        expect(
          current().readingHighlights.value.values,
          everyElement(const Color(0xFFFFF59D)),
        );
        expect(current().readingHighlights.value, hasLength(5));
        expect(current().textDelta, delta);
        select(current());
        current().highlightReadingSelection(null);
        await editor.selectPage('two');
        expect(
          current().readingHighlights.value.values,
          everyElement(const Color(0xFF90CAF9)),
        );
        await editor.selectPage('one');
        expect(current().readingHighlights.value, isEmpty);
        await editor.openBookletAtPath(directory.path);
        expect(current().readingHighlights.value, isEmpty);
      } finally {
        editor.dispose();
        theme.dispose();
        settings.dispose();
        await directory.delete(recursive: true);
      }
    },
  );
}
