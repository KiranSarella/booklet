import 'dart:async';

import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/_helpers/autoheight_richtext.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TextComponentState state;
  String? clipboardText;

  setUp(() {
    state = TextComponentState(Attribute.leftAlignment);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') {
            return {'text': clipboardText};
          }
          if (call.method == 'Clipboard.hasStrings') return {'value': true};
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String?;
          }
          return null;
        });
  });

  testWidgets('pastes the article from the context menu', (tester) async {
    clipboardText =
        'There are certain articles of food-stuff, exch of which,\n\n'
        'though harmless in itself, produces bad effects when com.\n\n'
        'bined, or eaten on the same day with some special articles.\n\n'
        'Such an incongenial combination of different kinds of dict\n\n'
        'gives rise to diseases, loss of strength, and vitality.';
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [FlutterQuillLocalizations.delegate],
        home: Scaffold(
          body: AutoHeightRichText2(
            visualState: state,
            isSelected: true,
            onSelect: () {},
            onCreateBelow: () {},
            textStyle: const TextStyle(fontSize: 16),
            alignment: Attribute.leftAlignment,
            placeholder: 'Text',
            gatePointerInput: false,
          ),
        ),
      ),
    );
    state.focusNode.requestFocus();
    await tester.pumpAndSettle();
    final editor = tester.state<QuillRawEditorState>(
      find.byType(QuillRawEditor),
    );
    editor.showToolbar();
    await tester.pumpAndSettle();
    Future<void> clickMenu(String label) async {
      final mouse = await tester.startGesture(
        tester.getCenter(find.text(label)),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      expect(state.focusNode.hasFocus, isTrue);
      await mouse.up();
      await tester.pumpAndSettle();
    }

    await clickMenu('Paste with fewer line breaks');
    expect(state.output, '${clipboardText!.replaceAll('\n\n', '\n')}\n');

    editor.showToolbar();
    await tester.pumpAndSettle();
    await clickMenu('Select All');
    expect(state.controller.selection.isCollapsed, isFalse);
    final selected = state.controller.plainTextEditingValue.selection
        .textInside(state.controller.plainTextEditingValue.text);

    editor.showToolbar();
    await tester.pumpAndSettle();
    await clickMenu('Copy');
    expect(clipboardText, selected);

    state.controller.updateSelection(
      TextSelection(baseOffset: 0, extentOffset: selected.length),
      ChangeSource.local,
    );
    await tester.pump();
    editor.showToolbar();
    await tester.pumpAndSettle();
    await clickMenu('Cut');
    expect(state.output, '\n');

    clipboardText = 'Regular paste works';
    editor.showToolbar();
    await tester.pumpAndSettle();
    await clickMenu('Paste');
    expect(state.output, 'Regular paste works\n');
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  tearDown(() {
    state.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('reduces newline runs and bypasses component splitting', () async {
    clipboardText = 'one\ntwo\n\nthree\n\n\nfour\r\nfive\r\r六';
    var splitCalled = false;
    state.onPasteText = (_) async {
      splitCalled = true;
      return true;
    };

    await state.pasteWithFewerLineBreaks();

    expect(state.output, 'one two\nthree\n\nfour five\n六\n');
    expect(splitCalled, isFalse);
  });

  test('keeps the insertion range while waiting for the clipboard', () async {
    state.controller.replaceText(0, 0, 'OLD suffix', null);
    state.controller.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 3),
      ChangeSource.local,
    );
    final clipboard = Completer<Object?>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) {
          return clipboard.future;
        });
    final paste = state.pasteWithFewerLineBreaks();
    state.controller.updateSelection(
      const TextSelection.collapsed(offset: 10),
      ChangeSource.local,
    );
    clipboard.complete({'text': 'new\ntext'});
    await paste;
    expect(state.output, 'new text suffix\n');
  });

  test('pastes at the end when the editor has no valid selection', () async {
    state.controller.replaceText(0, 0, 'existing ', null);
    state.controller.updateSelection(
      const TextSelection.collapsed(offset: -1),
      ChangeSource.local,
    );
    clipboardText = 'new\ntext';
    await state.pasteWithFewerLineBreaks();
    expect(state.output, 'existing new text\n');
  });

  test(
    'replaces the selection and places the caret after pasted text',
    () async {
      state.controller.replaceText(0, 0, 'before OLD after', null);
      state.controller.updateSelection(
        const TextSelection(baseOffset: 7, extentOffset: 10),
        ChangeSource.local,
      );
      clipboardText = 'new\ntext';

      await state.pasteWithFewerLineBreaks();

      expect(state.output, 'before new text after\n');
      expect(state.controller.selection.baseOffset, 15);
    },
  );

  test('does not modify read-only text or an empty clipboard', () async {
    clipboardText = '';
    await state.pasteWithFewerLineBreaks();
    expect(state.output, '\n');

    clipboardText = 'new\ntext';
    state.controller.readOnly = true;
    await state.pasteWithFewerLineBreaks();
    expect(state.output, '\n');
  });
}
