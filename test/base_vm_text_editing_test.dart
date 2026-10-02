import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/ui/base_vm.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DocumentSettingsController documentSettings;
  late PageSettingsController theme;
  late BaseVM viewModel;

  setUp(() {
    documentSettings = DocumentSettingsController();
    theme = PageSettingsController(documentSettings);
    viewModel = BaseVM(theme);
  });

  tearDown(() {
    viewModel.dispose();
    theme.dispose();
    documentSettings.dispose();
  });

  test('Enter splits text at the cursor and creates a text component', () {
    final source = viewModel.components[1];
    final sourceState = source.component.state as TextComponentState;
    sourceState.controller.replaceText(
      0,
      0,
      'hello world',
      const TextSelection.collapsed(offset: 5),
    );

    viewModel.createComponentBelow(
      1,
      selection: const TextSelection.collapsed(offset: 5),
    );

    expect(sourceState.output, 'hello\n');
    expect(
      (viewModel.components[2].component.state as TextComponentState).output,
      ' world\n',
    );
  });

  test('Backspace merges a non-empty text component into the previous one', () {
    final previous = viewModel.components[1];
    final previousState = previous.component.state as TextComponentState;
    previousState.controller.replaceText(
      0,
      0,
      'hello',
      const TextSelection.collapsed(offset: 5),
    );
    final previousEndOffset = previousState.controller.document.length - 1;
    final current = viewModel.createComponentBelow(1);
    final currentState = current.component.state as TextComponentState;
    currentState.controller.replaceText(
      0,
      0,
      ' world',
      const TextSelection.collapsed(offset: 6),
    );

    expect(viewModel.mergeTextComponentWithPrevious(2), same(previous));

    expect(viewModel.components, hasLength(2));
    expect(previousState.output, 'hello world\n');
    expect(viewModel.selectedComponent, same(previous));
    expect(previousState.controller.selection.extentOffset, previousEndOffset);
    expect(
      previousState.controller.selection.extentOffset,
      lessThan(previousState.controller.document.length - 1),
    );
  });

  test('Backspace removes an empty text component', () {
    final previous = viewModel.components[1];
    final current = viewModel.createComponentBelow(1);

    expect(viewModel.mergeTextComponentWithPrevious(2), same(previous));

    expect(viewModel.components, hasLength(2));
    expect(viewModel.components, isNot(contains(current)));
    expect(viewModel.selectedComponent, same(previous));
  });

  test(
    'Backspace removes an empty text component before a non-text component',
    () {
      final previous = viewModel.components.first;
      final current = viewModel.components[1];

      expect(viewModel.mergeTextComponentWithPrevious(1), same(previous));

      expect(viewModel.components, hasLength(1));
      expect(viewModel.components, isNot(contains(current)));
      expect(viewModel.selectedComponent, same(previous));
    },
  );
}
