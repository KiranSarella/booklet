import 'package:booklet/ui/components/composed/composed_component.dart';
import 'package:booklet/ui/components/composed/composition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/text_component.dart';
import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/editor_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/ui/detail/editor/editor_view.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/business/booklet_asset.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'nested text selection enables inline formatting for the focused child only',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final settings = DocumentSettingsController();
      final theme = PageSettingsController(settings);
      final controller = EditorController(theme, settings);
      final template = CompositionTemplate(
        'format',
        'Nested text',
        CompositionNode(
          'column',
          children: [
            CompositionNode(
              'row',
              children: [
                CompositionNode('text'),
                CompositionNode('inline_heading'),
              ],
            ),
          ],
        ),
      );
      await CompositionLibrary.save(template);
      final outer = controller.viewModel.createComponentBelowType(
        -1,
        template.key,
      );
      final state = outer.component.state as ComposedState;
      final fields = state.leaves.values
          .map((box) => box.component.state as TextComponentState)
          .toList();
      for (final field in fields) {
        field.replaceDocument(
          Document.fromJson([
            {'insert': 'Hello world\n'},
          ]),
        );
      }
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [FlutterQuillLocalizations.delegate],
          home: Scaffold(body: EditorView(controller: controller)),
        ),
      );
      for (final field in fields) {
        final editor = find.byWidgetPredicate(
          (w) => w is QuillEditor && w.focusNode == field.focusNode,
        );
        await tester.tapAt(tester.getCenter(editor));
        await tester.pump();
        field.controller.updateSelection(
          const TextSelection(baseOffset: 0, extentOffset: 5),
          ChangeSource.local,
        );
        await tester.pump();
        await tester.tap(
          find.byTooltip('More options'),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pump();
        for (final (label, attribute) in [
          ('Bold', Attribute.bold),
          ('Italic', Attribute.italic),
          ('Strikethrough', Attribute.strikeThrough),
          ('Inline code', Attribute.inlineCode),
        ]) {
          expect(find.byTooltip(label), findsOneWidget);
          await tester.tap(
            find.byTooltip(label),
            kind: PointerDeviceKind.mouse,
          );
          await tester.pump();
          expect(
            field.controller
                .getSelectionStyle()
                .attributes[attribute.key]
                ?.value,
            attribute.value,
          );
          expect(
            field.controller.selection,
            const TextSelection(baseOffset: 0, extentOffset: 5),
          );
          final sibling = fields.firstWhere((candidate) => candidate != field);
          expect(
            sibling.controller.document.toDelta().toJson().any(
              (op) =>
                  (op['attributes'] as Map?)?.containsKey(attribute.key) ??
                  false,
            ),
            isFalse,
          );
          await tester.tap(
            find.byTooltip(label),
            kind: PointerDeviceKind.mouse,
          );
          await tester.pump();
          expect(
            field.controller
                .getSelectionStyle()
                .attributes[attribute.key]
                ?.value,
            isNull,
          );
        }
        expect(outer.isSelected, isTrue);
        expect(state.leaves.values.every((box) => !box.isSelected), isTrue);
        field.controller.updateSelection(
          const TextSelection.collapsed(offset: 5),
          ChangeSource.local,
        );
        await tester.pump();
        expect(find.byTooltip('Bold'), findsNothing);
      }
      settings.updateEditMode(DocumentEditMode.readOnly);
      fields.first.controller.updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 5),
        ChangeSource.local,
      );
      await tester.pump();
      expect(find.byTooltip('Bold'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      theme.dispose();
      settings.dispose();
    },
  );
  testWidgets('more options formats only selected ranges in text components', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final settings = DocumentSettingsController();
    final theme = PageSettingsController(settings);
    final controller = EditorController(theme, settings);
    final box = controller.viewModel.components.firstWhere(
      (box) => box.component is TextComponent,
    );
    final state = box.component.state as TextComponentState;
    state.replaceDocument(
      Document.fromJson([
        {'insert': 'Hello world\n'},
      ]),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [FlutterQuillLocalizations.delegate],
        home: Scaffold(body: EditorView(controller: controller)),
      ),
    );
    controller.viewModel.selectComponent(box);
    state.focusNode.requestFocus();
    await tester.pump();
    await tester.tap(
      find.byTooltip('More options'),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    expect(find.byTooltip('Bold'), findsNothing);
    state.controller.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 5),
      ChangeSource.local,
    );
    await tester.pump();
    await tester.tap(
      find.byTooltip('More options'),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    for (final (label, attribute) in [
      ('Bold', Attribute.bold),
      ('Italic', Attribute.italic),
      ('Strikethrough', Attribute.strikeThrough),
      ('Inline code', Attribute.inlineCode),
    ]) {
      expect(find.byTooltip(label), findsOneWidget);
      expect(find.text(label), findsNothing);
      await tester.tap(find.byTooltip(label), kind: PointerDeviceKind.mouse);
      await tester.pump();
      expect(
        state.controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 5),
      );
      expect(
        state.controller.getSelectionStyle().attributes[attribute.key]?.value,
        attribute.value,
      );
      await tester.tap(find.byTooltip(label), kind: PointerDeviceKind.mouse);
      await tester.pump();
      expect(
        state.controller.getSelectionStyle().attributes[attribute.key]?.value,
        isNull,
      );
    }
    state.controller.updateSelection(
      const TextSelection.collapsed(offset: 5),
      ChangeSource.local,
    );
    await tester.pump();
    expect(find.byTooltip('Bold'), findsNothing);
    final heading = controller.viewModel.components.first;
    controller.viewModel.selectComponent(heading);
    final headingState = heading.component.state as TextComponentState;
    headingState.replaceDocument(
      Document.fromJson([
        {'insert': 'Heading\n'},
      ]),
    );
    headingState.focusNode.requestFocus();
    headingState.controller.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 4),
      ChangeSource.local,
    );
    await tester.pump();
    await tester.tap(
      find.byTooltip('More options'),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    expect(find.byTooltip('Bold'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    theme.dispose();
    settings.dispose();
  });

  testWidgets('mouse toolbar highlights selected read-only text', (
    tester,
  ) async {
    final settings = DocumentSettingsController();
    final theme = PageSettingsController(settings);
    final controller = EditorController(theme, settings);
    final state =
        controller.viewModel.components
                .firstWhere((box) => box.component.state is TextComponentState)
                .component
                .state
            as TextComponentState;
    state.replaceDocument(
      Document.fromJson([
        {'insert': 'Hello reader\n'},
      ]),
    );
    settings.updateEditMode(DocumentEditMode.readOnly);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [FlutterQuillLocalizations.delegate],
        home: Scaffold(body: EditorView(controller: controller)),
      ),
    );
    state.focusNode.requestFocus();
    await tester.pump();
    state.controller.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 5),
      ChangeSource.local,
    );
    await tester.pump();
    await tester.tap(
      find.byTooltip('Choose highlight color'),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(find.text('Pink'), findsNothing);
    await tester.tap(
      find.bySemanticsLabel('Pink'),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(state.readingHighlights.value, isEmpty);
    // Toolbar/keyboard navigation can move focus while selection survives.
    state.focusNode.unfocus();
    await tester.pump();
    expect(state.controller.selection.isCollapsed, isFalse);
    await tester.tap(
      find.byTooltip('Highlight selected text'),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(state.readingHighlights.value.length, 5);
    bool hasPink(InlineSpan span) =>
        span is TextSpan &&
        (span.style?.backgroundColor == const Color(0xFFF48FB1) ||
            (span.children?.any(hasPink) ?? false));
    expect(
      tester
          .widgetList<RichText>(find.byType(RichText))
          .any((widget) => hasPink(widget.text)),
      isTrue,
    );
    await tester.tap(
      find.byTooltip('Clear selected highlight'),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(state.readingHighlights.value, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    theme.dispose();
    settings.dispose();
  });

  for (final extend in [false, true]) {
    testWidgets('arrows reveal offscreen selection (extend: $extend)', (
      tester,
    ) async {
      final settings = DocumentSettingsController();
      final theme = PageSettingsController(settings);
      final controller = EditorController(theme, settings);
      for (var i = 0; i < 16; i++) {
        controller.viewModel.createComponentBelowType(i, 'text');
      }
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [FlutterQuillLocalizations.delegate],
          home: Scaffold(body: EditorView(controller: controller)),
        ),
      );
      final editor = tester.state<EditorViewState>(find.byType(EditorView));
      final components = controller.viewModel.components;
      final scroll = tester
          .widget<SingleChildScrollView>(
            find.byType(SingleChildScrollView).first,
          )
          .controller!;
      editor.selectComponent(components.first);
      await tester.pump();
      if (extend) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(scroll.offset, 0);
      for (var i = 2; i < components.length; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }
      expect(controller.viewModel.selectedComponent, same(components.last));
      expect(scroll.offset, greaterThan(0));
      final viewport = tester.getRect(find.byType(SingleChildScrollView).first);
      final lastRect = tester.getRect(find.byKey(components.last.componentKey));
      expect(lastRect.bottom, lessThanOrEqualTo(viewport.bottom + 1));
      for (var i = 1; i < components.length; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
      }
      expect(controller.viewModel.selectedComponent, same(components.first));
      final firstRect = tester.getRect(
        find.byKey(components.first.componentKey),
      );
      expect(firstRect.top, greaterThanOrEqualTo(viewport.top - 1));
      if (extend) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      theme.dispose();
      settings.dispose();
    });
  }

  testWidgets(
    'Enter focuses a selected text component without inserting text',
    (tester) async {
      final settings = DocumentSettingsController();
      final theme = PageSettingsController(settings);
      final controller = EditorController(theme, settings);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [FlutterQuillLocalizations.delegate],
          home: Scaffold(body: EditorView(controller: controller)),
        ),
      );
      final editor = tester.state<EditorViewState>(find.byType(EditorView));
      final component = controller.viewModel.components.firstWhere(
        (component) => component.isTextComponent,
      );
      final state = component.component.state as TextComponentState;
      final before = state.controller.document.toPlainText();
      for (final key in [
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.numpadEnter,
      ]) {
        editor.clearSelectionAndFocus();
        await tester.pump();
        editor.selectComponent(component);
        await tester.pump();
        expect(state.focusNode.hasFocus, isFalse);
        await tester.sendKeyEvent(key);
        await tester.pump();
        expect(state.focusNode.hasFocus, isTrue);
        expect(state.controller.document.toPlainText(), before);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      theme.dispose();
      settings.dispose();
    },
  );

  testWidgets('Alt+arrows scroll without selection or page focus', (
    tester,
  ) async {
    final settings = DocumentSettingsController();
    final theme = PageSettingsController(settings);
    final controller = EditorController(theme, settings);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [FlutterQuillLocalizations.delegate],
        home: Scaffold(body: EditorView(controller: controller)),
      ),
    );
    final editor = tester.state<EditorViewState>(find.byType(EditorView));
    editor.clearSelectionAndFocus();
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    final pageFocus = tester
        .widgetList<Focus>(find.byType(Focus))
        .singleWhere(
          (focus) => focus.focusNode?.debugLabel == 'page-shortcuts',
        );
    expect(pageFocus.focusNode!.hasFocus, isFalse);
    expect(controller.viewModel.selectedComponent, isNull);
    final scroll = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView).first)
        .controller!;
    expect(scroll.position.maxScrollExtent, greaterThan(0));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(scroll.offset, scroll.position.maxScrollExtent);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();
    expect(scroll.offset, scroll.position.minScrollExtent);
    expect(controller.viewModel.selectedComponent, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    theme.dispose();
    settings.dispose();
  });

  testWidgets('Alt+arrows scroll while a text component has focus', (
    tester,
  ) async {
    final settings = DocumentSettingsController();
    final theme = PageSettingsController(settings);
    final controller = EditorController(theme, settings);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [FlutterQuillLocalizations.delegate],
        home: Scaffold(body: EditorView(controller: controller)),
      ),
    );
    final editor = tester.state<EditorViewState>(find.byType(EditorView));
    final component = controller.viewModel.components.first;
    editor.selectComponent(component);
    await tester.pump();
    component.requestFocus();
    await tester.pumpAndSettle();
    expect(component.isFocused, isTrue);
    final scroll = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView).first)
        .controller!;

    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(scroll.offset, scroll.position.maxScrollExtent);
    expect(component.isFocused, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();
    expect(scroll.offset, scroll.position.minScrollExtent);
    expect(component.isFocused, isTrue);
    expect(controller.viewModel.selectedComponent, same(component));

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    theme.dispose();
    settings.dispose();
  });

  testWidgets('page scrolling shortcuts work after clicking empty space', (
    tester,
  ) async {
    final settings = DocumentSettingsController();
    final theme = PageSettingsController(settings);
    final controller = EditorController(theme, settings);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [FlutterQuillLocalizations.delegate],
        home: Scaffold(body: EditorView(controller: controller)),
      ),
    );
    final scroll = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView).first)
        .controller!;
    await tester.tapAt(const Offset(400, 550));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(scroll.offset, scroll.position.minScrollExtent);

    final selection = controller.viewModel.selectedComponent;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(scroll.offset, scroll.position.maxScrollExtent);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();
    expect(scroll.offset, scroll.position.minScrollExtent);
    expect(controller.viewModel.selectedComponent, same(selection));

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    theme.dispose();
    settings.dispose();
  });

  testWidgets('Alt+F opens page search', (tester) async {
    final settings = DocumentSettingsController();
    final theme = PageSettingsController(settings);
    final controller = EditorController(theme, settings);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [FlutterQuillLocalizations.delegate],
        home: Scaffold(body: EditorView(controller: controller)),
      ),
    );
    await tester.tap(find.byType(EditorView));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Find in page'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    theme.dispose();
    settings.dispose();
  });

  testWidgets('asset selection owns arrow navigation and releases focus', (
    tester,
  ) async {
    final settings = DocumentSettingsController();
    final theme = PageSettingsController(settings);
    final controller = EditorController(theme, settings);
    final box = controller.viewModel.createComponentBelowType(0, 'assets');
    final state = box.component.state as AssetsComponentState;
    state.folder.assets.addAll([
      const BookletAsset(id: 'z', name: 'zeta.txt', path: 'zeta.txt'),
      const BookletAsset(id: 'a', name: 'alpha.txt', path: 'alpha.txt'),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [FlutterQuillLocalizations.delegate],
        home: Scaffold(body: EditorView(controller: controller)),
      ),
    );
    await tester.ensureVisible(find.text('alpha.txt'));
    await tester.tap(find.text('alpha.txt'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(state.isFocused, isTrue);
    expect(controller.viewModel.selectedComponent, same(box));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(state.controller.selectedAsset?.id, 'z');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(state.controller.selectedAsset?.id, 'a');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(state.controller.selectedAsset?.id, 'a');
    expect(controller.viewModel.selectedComponents, {box});
    final editor = tester.state<EditorViewState>(find.byType(EditorView));
    editor.selectComponent(controller.viewModel.components.first);
    await tester.pump();
    expect(state.isFocused, isFalse);
    expect(state.focusNode.hasFocus, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    theme.dispose();
    settings.dispose();
  });

  for (final key in [
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
  ]) {
    testWidgets('Shift+$key selects components only outside edit mode', (
      tester,
    ) async {
      final settings = DocumentSettingsController();
      final theme = PageSettingsController(settings);
      final controller = EditorController(theme, settings);
      controller.viewModel.createComponentBelowType(1, 'text');
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [FlutterQuillLocalizations.delegate],
          home: Scaffold(body: EditorView(controller: controller)),
        ),
      );
      final editor = tester.state<EditorViewState>(find.byType(EditorView));
      final selected = controller.viewModel.components[1];
      editor.selectComponent(selected);
      await tester.pump();
      selected.requestFocus();
      await tester.pump();
      expect(selected.isFocused, isTrue);

      // Exercise the page handler even when the text editor would normally
      // consume the event before it bubbles to the page.
      final pageFocus = tester
          .widgetList<Focus>(find.byType(Focus))
          .singleWhere(
            (focus) => focus.focusNode?.debugLabel == 'page-shortcuts',
          );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      expect(
        pageFocus.onKeyEvent!(
          pageFocus.focusNode!,
          KeyDownEvent(
            physicalKey: key == LogicalKeyboardKey.arrowUp
                ? PhysicalKeyboardKey.arrowUp
                : PhysicalKeyboardKey.arrowDown,
            logicalKey: key,
            timeStamp: Duration.zero,
          ),
        ),
        KeyEventResult.ignored,
      );
      expect(controller.viewModel.selectedComponents, {selected});
      expect(selected.isFocused, isTrue);

      selected.clearFocus();
      editor.selectComponent(selected);
      await tester.pump();
      await tester.sendKeyEvent(key);
      expect(controller.viewModel.selectedComponents, hasLength(2));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      theme.dispose();
      settings.dispose();
    });
  }
}
