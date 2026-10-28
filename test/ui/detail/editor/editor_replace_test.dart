import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/detail/editor/editor_vm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final state = vm.components[1].component.state as TextComponentState;
    state.controller.replaceText(
      0,
      0,
      'Cat cat cat',
      const TextSelection.collapsed(offset: 11),
    );
  });
  tearDown(() {
    vm.dispose();
    theme.dispose();
    settings.dispose();
  });
  String text() =>
      (vm.components[1].component.state as TextComponentState).output;

  test('replace targets one occurrence and honors case sensitivity', () {
    expect(
      vm.replaceSearchMatches('cat', 'dog', caseSensitive: true, matchIndex: 1),
      1,
    );
    expect(text(), 'Cat cat dog\n');
  });

  test('replace all preserves offsets and undoes as one operation', () {
    expect(vm.replaceSearchMatches('cat', 'kitten'), 3);
    expect(text(), 'kitten kitten kitten\n');
    vm.undo();
    expect(text(), 'Cat cat cat\n');
    vm.redo();
    expect(text(), 'kitten kitten kitten\n');
  });

  test('replacement can delete matches or include the search query', () {
    expect(vm.replaceSearchMatches('cat', 'catcat'), 3);
    expect(text(), 'catcat catcat catcat\n');
    expect(vm.replaceSearchMatches('catcat', ''), 3);
    expect(text(), '  \n');
  });

  test('read-only mode prevents both replace and replace all', () {
    settings.updateEditMode(DocumentEditMode.readOnly);
    expect(vm.replaceSearchMatches('cat', 'dog', matchIndex: 0), 0);
    expect(vm.replaceSearchMatches('cat', 'dog'), 0);
    expect(text(), 'Cat cat cat\n');
    settings.updateEditMode(DocumentEditMode.edit);
    expect(vm.replaceSearchMatches('cat', 'dog'), 3);
    expect(text(), 'dog dog dog\n');
  });
}
