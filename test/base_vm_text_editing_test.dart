import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/ui/base_vm.dart';
import 'package:booklet/ui/components/component_snapshot.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/page_view/page_view.dart';
import 'package:flutter/material.dart' hide PageView;
import 'package:flutter/services.dart';
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

  test('Enter continues a bullet list and inherits its item settings', () {
    final bullet = viewModel.createComponentBelowType(1, 'bulleted_list');
    final bulletState = bullet.component.state as BulletedListComponentState
      ..symbol = '→'
      ..nestingLevel = 2;
    bulletState.controller.replaceText(
      0,
      0,
      'first item',
      const TextSelection.collapsed(offset: 11),
    );

    final next = viewModel.createComponentBelow(
      2,
      selection: const TextSelection.collapsed(offset: 5),
    );
    final nextState = next.component.state as BulletedListComponentState;

    expect(next.component.def.key, 'bulleted_list');
    expect(bulletState.output, 'first\n');
    expect(nextState.output, ' item\n');
    expect(nextState.symbol, '→');
    expect(nextState.nestingLevel, 2);
  });

  test('Enter on an empty list item converts it to text in place', () {
    final bullet = viewModel.createComponentBelowType(1, 'bulleted_list');

    final result = viewModel.createComponentBelow(
      2,
      selection: const TextSelection.collapsed(offset: 0),
    );

    expect(result, same(bullet));
    expect(viewModel.components, hasLength(3));
    expect(bullet.component.def.key, 'text');
  });

  test('Enter outdents an empty nested list before converting it to text', () {
    final bullet = viewModel.createComponentBelowType(1, 'bulleted_list');
    final state = bullet.component.state as BulletedListComponentState
      ..nestingLevel = 2;

    for (final expectedLevel in [1, 0]) {
      expect(
        viewModel.createComponentBelow(
          2,
          selection: const TextSelection.collapsed(offset: 0),
        ),
        same(bullet),
      );
      expect(state.nestingLevel, expectedLevel);
      expect(bullet.component.def.key, 'bulleted_list');
    }

    expect(
      viewModel.createComponentBelow(
        2,
        selection: const TextSelection.collapsed(offset: 0),
      ),
      same(bullet),
    );
    expect(bullet.component.def.key, 'text');
  });

  test(
    'Enter outdents an empty nested checklist before converting to text',
    () {
      final checklist = viewModel.createComponentBelowType(1, 'checklist');
      final state = checklist.component.state as ChecklistComponentState
        ..nestingLevel = 2
        ..isChecked = true;

      for (final expectedLevel in [1, 0]) {
        expect(
          viewModel.createComponentBelow(
            2,
            selection: const TextSelection.collapsed(offset: 0),
          ),
          same(checklist),
        );
        expect(state.nestingLevel, expectedLevel);
        expect(state.isChecked, isTrue);
        expect(checklist.component.def.key, 'checklist');
      }

      viewModel.createComponentBelow(
        2,
        selection: const TextSelection.collapsed(offset: 0),
      );
      expect(checklist.component.def.key, 'text');
    },
  );

  test('Enter continues numbered and checklist components', () {
    final numbered = viewModel.createComponentBelowType(1, 'numbered_list');
    final numberedState = numbered.component.state as NumberedListComponentState
      ..numberStyle = 'a.'
      ..nestingLevel = 1;
    numberedState.controller.replaceText(
      0,
      0,
      'one',
      const TextSelection.collapsed(offset: 3),
    );
    final nextNumbered = viewModel.createComponentBelow(
      2,
      selection: const TextSelection.collapsed(offset: 3),
    );
    final nextNumberedState =
        nextNumbered.component.state as NumberedListComponentState;

    expect(nextNumbered.component.def.key, 'numbered_list');
    expect(nextNumberedState.numberStyle, 'a.');
    expect(nextNumberedState.nestingLevel, 1);

    final checklist = viewModel.createComponentBelowType(3, 'checklist');
    final checklistState = checklist.component.state as ChecklistComponentState
      ..nestingLevel = 2
      ..isChecked = true;
    checklistState.controller.replaceText(
      0,
      0,
      'checked',
      const TextSelection.collapsed(offset: 7),
    );
    final nextChecklist = viewModel.createComponentBelow(
      4,
      selection: const TextSelection.collapsed(offset: 7),
    );
    final nextChecklistState =
        nextChecklist.component.state as ChecklistComponentState;

    expect(nextChecklist.component.def.key, 'checklist');
    expect(nextChecklistState.nestingLevel, 2);
    expect(nextChecklistState.isChecked, isFalse);
  });

  test('list component snapshots retain display options and nesting', () {
    final bullet = viewModel.createComponentBelowType(1, 'bulleted_list');
    final bulletState = bullet.component.state as BulletedListComponentState
      ..symbol = '★'
      ..nestingLevel = 2;
    final numbered = viewModel.createComponentBelowType(2, 'numbered_list');
    final numberedState = numbered.component.state as NumberedListComponentState
      ..numberStyle = 'i.'
      ..nestingLevel = 1;
    final checklist = viewModel.createComponentBelowType(3, 'checklist');
    final checklistState = checklist.component.state as ChecklistComponentState
      ..isChecked = true
      ..nestingLevel = 3;

    final copies = [
      for (final component in [bullet, numbered, checklist])
        ComponentSnapshot.capture(component).instantiate(),
    ];

    expect(
      (copies[0].component.state as BulletedListComponentState).symbol,
      '★',
    );
    expect(
      (copies[0].component.state as BulletedListComponentState).nestingLevel,
      2,
    );
    expect(
      (copies[1].component.state as NumberedListComponentState).numberStyle,
      'i.',
    );
    expect(
      (copies[1].component.state as NumberedListComponentState).nestingLevel,
      1,
    );
    expect(
      (copies[2].component.state as ChecklistComponentState).isChecked,
      isTrue,
    );
    expect(
      (copies[2].component.state as ChecklistComponentState).nestingLevel,
      3,
    );
    for (final copy in copies) {
      copy.dispose();
    }
  });

  test('changing one bullet symbol updates all bullets at its level', () {
    final first = viewModel.createComponentBelowType(1, 'bulleted_list');
    final firstState = first.component.state as BulletedListComponentState;
    final nested = viewModel.createComponentBelowType(2, 'bulleted_list');
    final nestedState = nested.component.state as BulletedListComponentState
      ..nestingLevel = 1;
    final sameLevel = viewModel.createComponentBelowType(3, 'bulleted_list');
    final sameLevelState =
        sameLevel.component.state as BulletedListComponentState;

    viewModel.selectComponent(first);
    viewModel.setSelectedListStyle('★');

    expect(firstState.symbol, '★');
    expect(sameLevelState.symbol, '★');
    expect(nestedState.symbol, '•');
  });

  test('changing a bullet symbol applies to all selected bullet items', () {
    final first = viewModel.createComponentBelowType(1, 'bulleted_list');
    final firstState = first.component.state as BulletedListComponentState;
    final second = viewModel.createComponentBelowType(2, 'bulleted_list');
    final secondState = second.component.state as BulletedListComponentState;
    final unselected = viewModel.createComponentBelowType(3, 'bulleted_list');
    final unselectedState =
        unselected.component.state as BulletedListComponentState;

    viewModel.selectComponent(first);
    viewModel.selectComponentRange(second);
    viewModel.setSelectedListStyle('✓');

    expect(firstState.symbol, '✓');
    expect(secondState.symbol, '✓');
    expect(unselectedState.symbol, '•');
  });

  test('changing one number style updates numbered items at its level', () {
    final first = viewModel.createComponentBelowType(1, 'numbered_list');
    final firstState = first.component.state as NumberedListComponentState;
    final nested = viewModel.createComponentBelowType(2, 'numbered_list');
    final nestedState = nested.component.state as NumberedListComponentState
      ..nestingLevel = 1;
    final sameLevel = viewModel.createComponentBelowType(3, 'numbered_list');
    final sameLevelState =
        sameLevel.component.state as NumberedListComponentState;

    viewModel.selectComponent(first);
    viewModel.setSelectedListStyle('i.');

    expect(firstState.numberStyle, 'i.');
    expect(sameLevelState.numberStyle, 'i.');
    expect(nestedState.numberStyle, '1.');
  });

  test('changing a number style applies to selected numbered items', () {
    final first = viewModel.createComponentBelowType(1, 'numbered_list');
    final firstState = first.component.state as NumberedListComponentState;
    final second = viewModel.createComponentBelowType(2, 'numbered_list');
    final secondState = second.component.state as NumberedListComponentState;
    final unselected = viewModel.createComponentBelowType(3, 'numbered_list');
    final unselectedState =
        unselected.component.state as NumberedListComponentState;

    viewModel.selectComponent(first);
    viewModel.selectComponentRange(second);
    viewModel.setSelectedListStyle('a.');

    expect(firstState.numberStyle, 'a.');
    expect(secondState.numberStyle, 'a.');
    expect(unselectedState.numberStyle, '1.');
  });

  testWidgets('renders list markers and toggles checklist items', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    viewModel.createComponentBelowType(1, 'numbered_list');
    final nestedFirst = viewModel.createComponentBelowType(2, 'numbered_list');
    (nestedFirst.component.state as NumberedListComponentState)
      ..numberStyle = 'a.'
      ..nestingLevel = 1;
    final nestedSecond = viewModel.createComponentBelowType(3, 'numbered_list');
    (nestedSecond.component.state as NumberedListComponentState)
      ..numberStyle = 'a.'
      ..nestingLevel = 1;
    viewModel.createComponentBelowType(4, 'numbered_list');
    viewModel.createComponentBelowType(5, 'text');
    final restartedNumbering = viewModel.createComponentBelowType(
      6,
      'numbered_list',
    );
    (restartedNumbering.component.state as NumberedListComponentState)
            .numberStyle =
        'i.';
    final bullet = viewModel.createComponentBelowType(7, 'bulleted_list');
    final bulletState = bullet.component.state as BulletedListComponentState
      ..symbol = '→'
      ..nestingLevel = 1;
    final numberedState =
        restartedNumbering.component.state as NumberedListComponentState;
    final checklist = viewModel.createComponentBelowType(8, 'checklist');
    final checklistState = checklist.component.state as ChecklistComponentState;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PageView(
              editorTheme: theme,
              page: viewModel.selectedPage,
              onSelectComponent: (_) {},
              onSelectComponentRange: (_) {},
              onCreateEntryBelow: (_, __) {},
              onBackspaceAtStart: (_) {},
              onTapEmptySpace: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('1.'), findsOneWidget);
    expect(find.text('2.'), findsOneWidget);
    expect(find.text('a.'), findsOneWidget);
    expect(find.text('b.'), findsOneWidget);
    expect(find.text('i.'), findsOneWidget);
    expect(find.text('→'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);

    bulletState.focusNode.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    expect(bulletState.nestingLevel, 2);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(bulletState.nestingLevel, 1);

    numberedState.focusNode.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    expect(numberedState.nestingLevel, 1);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(numberedState.nestingLevel, 0);

    checklistState.focusNode.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    expect(checklistState.nestingLevel, 1);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(checklistState.nestingLevel, 0);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(checklistState.isChecked, isTrue);
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
