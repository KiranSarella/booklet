import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/editor_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/ui/detail/editor/editor_view.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/business/booklet_asset.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
