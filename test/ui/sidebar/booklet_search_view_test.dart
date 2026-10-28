import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/editor_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/main_view.dart';
import 'package:booklet/ui/sidebar/booklet_search_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'toolbar and shortcut open search; clear and close end the query',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = DocumentSettingsController();
      final theme = PageSettingsController(settings);
      final editor = EditorController(theme, settings);
      final box = editor.viewModel.createComponentBelowType(0, 'text');
      final state = box.component.state as TextComponentState;
      state.controller.replaceText(
        0,
        0,
        'A unique needle here',
        state.controller.selection,
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [FlutterQuillLocalizations.delegate],
          home: Scaffold(
            body: MainView(controller: editor, onOpenInNewWindow: () {}),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Search booklet (Ctrl/Cmd+Shift+F)'));
      await tester.pumpAndSettle();
      final field = find.descendant(
        of: find.byType(BookletSearchView),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, 'needle');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('1 content match across 1 page'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(BookletSearchView),
          matching: find.textContaining('A unique ', findRichText: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Find in page'), findsNothing);
      expect(find.byTooltip('Close search (Esc)'), findsNothing);
      expect(state.controller.selection.isCollapsed, isFalse);
      expect(
        state.controller.selection.textInside(
          state.controller.document.toPlainText(),
        ),
        'needle',
      );
      await tester.tap(find.byTooltip('Close booklet search'));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Close booklet search'), findsOneWidget);
      expect(tester.widget<TextField>(field).controller!.text, '');
      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
      Finder inSearch(Finder matching) => find.descendant(
        of: find.byType(BookletSearchView),
        matching: matching,
      );
      await tester.enterText(field, 'NEEDLE');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.tap(inSearch(find.byTooltip('Match case')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('No results found.'), findsOneWidget);
      await tester.tap(inSearch(find.byTooltip('Match case')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.tap(inSearch(find.byTooltip('Show replace')));
      await tester.pumpAndSettle();
      await tester.enterText(inSearch(find.byType(TextField)).last, 'pin');
      await tester.tap(inSearch(find.text('Replace all')));
      await tester.pumpAndSettle();
      expect(state.controller.document.toPlainText(), contains('pin'));
      await tester.tap(inSearch(find.byTooltip('Clear search')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field.first).controller!.text, '');
      await tester.tap(inSearch(find.byTooltip('Close booklet search')));
      await tester.pumpAndSettle();
      expect(find.byType(BookletSearchView), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      editor.dispose();
      theme.dispose();
      settings.dispose();
    },
  );
}
