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
