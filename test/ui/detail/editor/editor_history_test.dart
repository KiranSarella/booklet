import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/editor_controller.dart';
import 'package:booklet/ui/detail/editor/editor_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/detail/editor/editor_vm.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DocumentSettingsController settings;
  late PageSettingsController theme;
  late EditorVM vm;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    settings = DocumentSettingsController();
    theme = PageSettingsController(settings);
    vm = EditorVM(theme);
  });
  tearDown(() {
    vm.dispose();
    theme.dispose();
    settings.dispose();
  });
  String text(int index) =>
      (vm.components[index].component.state as TextComponentState).output;
  void type(String value) {
    final state = vm.components[1].component.state as TextComponentState;
    state.controller.replaceText(
      0,
      0,
      value,
      TextSelection.collapsed(offset: value.length),
    );
  }

  test(
    'typing groups, selection does not create an edit, and redo branches',
    () {
      type('a');
      type('b');
      vm.undo();
      expect(text(1), '\n');
      expect(vm.canUndo, false);
      vm.redo();
      expect(text(1), 'ba\n');
      vm.undo();
      type('c');
      expect(vm.canRedo, false);
    },
  );
  test('split and merge are atomic and preserve component IDs', () {
    type('hello world');
    final id = vm.components[1].component.id;
    vm.createComponentBelow(
      1,
      selection: const TextSelection.collapsed(offset: 5),
    );
    final newId = vm.components[2].component.id;
    vm.undo();
    expect(vm.components.length, 2);
    expect(text(1), 'hello world\n');
    expect(vm.components[1].component.id, id);
    vm.redo();
    expect(vm.components[2].component.id, newId);
    vm.mergeTextComponentWithPrevious(2);
    vm.undo();
    expect(text(1), 'hello\n');
    expect(text(2), ' world\n');
  });
  test('multi component delete restores all components in one step', () {
    vm.selectComponent(vm.components.first);
    vm.selectComponentRange(vm.components.last);
    final ids = vm.components.map((box) => box.component.id).toList();
    vm.deleteSelectedComponent();
    expect(vm.components, isEmpty);
    vm.undo();
    expect(vm.components.map((box) => box.component.id), ids);
    vm.redo();
    expect(vm.components, isEmpty);
  });
  test('multiline paste is a single transaction', () {
    vm.pasteTextLines(1, 'one\ntwo\nthree');
    expect(vm.components.length, 4);
    vm.undo();
    expect(vm.components.length, 2);
    expect(text(1), '\n');
    expect(vm.canUndo, false);
  });
  test('page history is independent and navigation rename is excluded', () {
    type('first');
    final first = vm.selectedPageId!;
    vm.addChildPageSelected();
    final second = vm.selectedPageId!;
    expect(vm.canUndo, false);
    vm.renameSelectedNode('renamed');
    expect(vm.canUndo, false);
    vm.selectPage(first);
    expect(vm.canUndo, true);
    vm.undo();
    expect(text(1), '\n');
    vm.selectPage(second);
    expect(vm.canUndo, false);
  });

  test('read-only mode disables replay', () {
    type('saved');
    settings.updateEditMode(DocumentEditMode.readOnly);
    expect(vm.canUndo, false);
    vm.undo();
    expect(text(1), 'saved\n');
  });

  testWidgets(
    'editor shortcuts override focused text history and support redo',
    (tester) async {
      final controller = EditorController(theme, settings);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [FlutterQuillLocalizations.delegate],
          home: Scaffold(body: EditorView(controller: controller)),
        ),
      );
      final editor = tester.state<EditorViewState>(find.byType(EditorView));
      final box = controller.viewModel.components[1];
      editor.selectComponent(box);
      await tester.pump();
      box.requestFocus();
      await tester.pump();
      (box.component.state as TextComponentState).controller.replaceText(
        0,
        0,
        'hello',
        const TextSelection.collapsed(offset: 5),
      );
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(
        (controller.viewModel.components[1].component.state
                as TextComponentState)
            .output,
        '\n',
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(
        (controller.viewModel.components[1].component.state
                as TextComponentState)
            .output,
        'hello\n',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
}
