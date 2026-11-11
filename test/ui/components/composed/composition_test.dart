import 'package:booklet/ui/components/inbuilt_components/inbuilt_components.dart';
import 'package:booklet/ui/components/composed/composition_preview.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/image_component.dart';
import 'package:booklet/application/editor_controller.dart';
import 'package:booklet/ui/detail/editor/editor_view.dart';
import 'package:flutter/services.dart';
import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:booklet/ui/components/composed/composition.dart';
import 'package:booklet/ui/components/composed/composed_component.dart';
import 'package:booklet/ui/components/composed/composition_canvas.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_snapshot.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/detail/editor/options_dock/add_component_menu.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CompositionLibrary.templates.clear();
    CompositionLibrary.documentTemplates.clear();
  });
  CompositionTemplate template() => CompositionTemplate(
    'example',
    'Callout',
    CompositionNode(
      'column',
      focusBar: true,
      alignment: 'center',
      children: [
        CompositionNode('inline_heading', percent: 30),
        CompositionNode('text', percent: 70),
      ],
    ),
  );
  testWidgets(
    'nested text focuses without selecting children or stealing page focus',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final document = DocumentSettingsController();
      final theme = PageSettingsController(document);
      final controller = EditorController(theme, document);
      final layout = template();
      CompositionLibrary.templates.add(layout);
      final outer = controller.viewModel.createComponentBelowType(
        -1,
        layout.key,
      );
      final component = outer.component as ComposedComponent;
      final children = component.state.leaves.values.toList();
      final first = children.first.component.state as TextComponentState;
      final second = children.last.component.state as TextComponentState;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [FlutterQuillLocalizations.delegate],
          home: Scaffold(body: EditorView(controller: controller)),
        ),
      );
      Finder editor(TextComponentState state) => find.byWidgetPredicate(
        (w) => w is QuillEditor && w.focusNode == state.focusNode,
      );
      await tester.tapAt(tester.getCenter(editor(first)));
      await tester.pumpAndSettle();
      expect(outer.isSelected, isTrue);
      expect(outer.component.state.isFocused, isFalse);
      expect(outer.isFocused, isTrue);
      expect(children.every((box) => !box.isSelected), isTrue);
      expect(first.focusNode.hasFocus, isTrue);
      expect(first.isFocused, isTrue);
      expect(tester.testTextInput.hasAnyClients, isTrue);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Editable nested text\n',
          selection: TextSelection.collapsed(offset: 20),
        ),
      );
      await tester.pump();
      expect(first.output, contains('Editable nested text'));
      final count = controller.viewModel.components.length;
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(controller.viewModel.components.length, count);
      expect(first.output, contains('Editable nested text\n'));
      await tester.tapAt(tester.getCenter(editor(second)));
      await tester.pumpAndSettle();
      expect(first.focusNode.hasFocus, isFalse);
      expect(first.isFocused, isFalse);
      expect(second.focusNode.hasFocus, isTrue);
      expect(children.every((box) => !box.isSelected), isTrue);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Second child\n',
          selection: TextSelection.collapsed(offset: 12),
        ),
      );
      await tester.pump();
      expect(second.output, contains('Second child'));
      final other = controller.viewModel.components.firstWhere(
        (box) => box != outer,
      );
      final otherState = other.component.state as TextComponentState;
      await tester.tapAt(tester.getCenter(editor(otherState)));
      await tester.pumpAndSettle();
      expect(outer.isSelected, isFalse);
      expect(second.focusNode.hasFocus, isFalse);
      expect(outer.isFocused, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      theme.dispose();
      document.dispose();
    },
  );
  testWidgets(
    'document components offer insertion and a personal copy but no editing',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final document = CompositionLibrary.registerDocument(template());
      final original = jsonEncode(document.toJson());
      CompositionLibrary.registerDocument(
        CompositionTemplate(
          'other',
          'Other document',
          CompositionNode('column'),
        ),
      );
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddComponentMenu(
              title: 'Components',
              documentComponents: [document],
              onSelected: (key) => selected = key,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Composed'));
      await tester.pumpAndSettle();
      expect(find.text('My components'), findsOneWidget);
      expect(find.text('In this document'), findsOneWidget);
      expect(find.text('Other document'), findsNothing);
      expect(find.byTooltip('Edit composed component'), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      await tester.tap(find.text('Callout'));
      expect(selected, document.key);
      selected = null;
      await tester.tap(find.byTooltip('Add to personal components'));
      await tester.pumpAndSettle();
      expect(selected, isNull);
      expect(CompositionLibrary.templates.length, 1);
      final personal = CompositionLibrary.templates.single;
      expect(personal.id, isNot(document.id));
      expect(find.byTooltip('Edit composed component'), findsOneWidget);
      expect(find.text('Callout'), findsOneWidget);
      expect(find.byTooltip('Add to personal components'), findsNothing);
      await tester.tap(find.byTooltip('Edit composed component'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(CompositionCanvas),
          matching: find.byType(TextField),
        ),
        'Personal callout',
      );
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(CompositionLibrary.templates.single.name, 'Personal callout');
      expect(jsonEncode(document.toJson()), original);
      await CompositionLibrary.load();
      expect(CompositionLibrary.templates.single.name, 'Personal callout');
      expect(CompositionLibrary.personalCopyOf(document), isNotNull);
      expect(find.text('Callout'), findsNothing);
      await expectLater(CompositionLibrary.save(document), throwsStateError);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'read-only documents expose no insertion, editing, conversion, or compose actions',
    (tester) async {
      await CompositionLibrary.save(template());
      final document = CompositionLibrary.registerDocument(
        CompositionTemplate(
          'doc',
          'Document-only',
          CompositionNode('column', children: [CompositionNode('text')]),
        ),
      );
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddComponentMenu(
              title: 'Components',
              isReadOnly: true,
              documentComponents: [document],
              onSelected: (key) => selected = key,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Composed'));
      await tester.pumpAndSettle();
      expect(find.text('My components'), findsOneWidget);
      expect(find.text('In this document'), findsOneWidget);
      expect(find.text('Callout'), findsOneWidget);
      expect(find.text('Document-only'), findsOneWidget);
      expect(find.byTooltip('Edit composed component'), findsNothing);
      expect(find.byTooltip('Add to personal components'), findsNothing);
      expect(find.text('Compose component'), findsNothing);
      await tester.tap(find.text('Callout'));
      await tester.tap(find.text('Document-only'));
      expect(selected, isNull);
      expect(CompositionLibrary.templates.length, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'document definitions already in My components appear only once in search',
    (tester) async {
      final personal = template();
      await CompositionLibrary.save(personal);
      final document = CompositionLibrary.registerDocument(personal);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddComponentMenu(
              title: 'Components',
              documentComponents: [document],
              onSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'callout');
      await tester.pumpAndSettle();
      expect(find.text('Callout'), findsOneWidget);
      expect(find.byTooltip('Edit composed component'), findsOneWidget);
      expect(find.byTooltip('Add to personal components'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'existing instances render current padding and spacing without replacing content',
    (tester) async {
      final personal = template();
      await CompositionLibrary.save(personal);
      final instance = InbuiltComponents.prepareCompoent(
        'instance',
        personal.key,
      ) as ComposedComponent;
      final id = instance.state.template.id;
      final leaf = instance.state.leaves.values.last;
      final text = leaf.component.state as TextComponentState;
      text.controller.document.insert(0, 'Keep my text');
      final document = DocumentSettingsController();
      final theme = PageSettingsController(document);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [FlutterQuillLocalizations.delegate],
          home: Scaffold(
            body: SingleChildScrollView(
              child: instance.buildUI(
                theme: theme,
                componentState: instance.state,
                isSelected: false,
                onSelect: () {},
                onCreateBelow: () {},
              ),
            ),
          ),
        ),
      );
      final edited = CompositionTemplate.fromJson(personal.toJson());
      edited.root.horizontalPadding = 50;
      edited.root.spacing = 22;
      await CompositionLibrary.save(edited);
      await tester.pumpAndSettle();
      expect(instance.state.template.id, id);
      expect(instance.state.template.root.horizontalPadding, 50);
      expect(instance.state.template.root.spacing, 22);
      expect(instance.state.leaves.values.last, same(leaf));
      expect(text.output, 'Keep my text\n');
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.padding ==
                  const EdgeInsets.symmetric(horizontal: 50, vertical: 8),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is SizedBox && w.height == 22 && w.width == 22,
        ),
        findsOneWidget,
      );
      expect(
        jsonEncode(instance.state.toJson()),
        isNot(contains('horizontalPadding')),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      instance.dispose();
      theme.dispose();
      document.dispose();
    },
  );
  testWidgets(
    'menu edits the saved template without inserting it or changing page content',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final original = template();
      await CompositionLibrary.save(original);
      final instance = ComposedComponent(
        'existing',
        CompositionTemplate.fromJson(original.toJson()),
      );
      (instance.state.leaves.values.first.component.state as TextComponentState)
          .controller
          .document
          .insert(0, 'Existing page content');
      final before = jsonEncode(instance.state.toJson());
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddComponentMenu(
              title: 'Components',
              onSelected: (value) => selected = value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Composed'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit composed component'));
      await tester.pumpAndSettle();
      expect(selected, isNull);
      expect(find.widgetWithText(TextField, 'Callout'), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(CompositionCanvas),
          matching: find.byType(TextField),
        ),
        'Edited callout',
      );
      await tester.tap(find.text('TEXT · 70%'));
      await tester.pump();
      await tester.tap(find.byTooltip('Move earlier'));
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(selected, isNull);
      expect(find.text('Edited callout'), findsOneWidget);
      expect(CompositionLibrary.templates.length, 1);
      expect(CompositionLibrary.templates.single.id, original.id);
      expect(
        CompositionLibrary.templates.single.root.children.first.kind,
        'text',
      );
      expect(jsonEncode(instance.state.toJson()), before);
      expect(instance.state.template.name, 'Edited callout');
      await CompositionLibrary.load();
      expect(CompositionLibrary.templates.single.name, 'Edited callout');
      final saved = jsonEncode(CompositionLibrary.templates.single.toJson());
      await tester.tap(find.byTooltip('Edit composed component'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(CompositionCanvas),
          matching: find.byType(TextField),
        ),
        'Cancel me',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(jsonEncode(CompositionLibrary.templates.single.toJson()), saved);
      await tester.tap(find.text('Edited callout'));
      expect(selected, original.key);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      instance.dispose();
    },
  );
  testWidgets('page composition has no edit action even while selected', (
    tester,
  ) async {
    final document = DocumentSettingsController();
    final theme = PageSettingsController(document);
    final component = ComposedComponent('page', template());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: component.buildUI(
            theme: theme,
            componentState: component.state,
            isSelected: true,
            onSelect: () {},
            onCreateBelow: () {},
          ),
        ),
        localizationsDelegates: const [FlutterQuillLocalizations.delegate],
      ),
    );
    expect(find.byTooltip('Edit composed component'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    component.dispose();
    theme.dispose();
    document.dispose();
  });
  test(
    'legacy padding migrates to both axes and independent values persist',
    () async {
      final legacy = CompositionNode.fromJson({
        'kind': 'column',
        'padding': 18,
      });
      expect(legacy.horizontalPadding, 18);
      expect(legacy.verticalPadding, 18);
      legacy.horizontalPadding = 28;
      legacy.verticalPadding = 6;
      await CompositionLibrary.save(
        CompositionTemplate('padding', 'Padding', legacy),
      );
      await CompositionLibrary.load();
      final restored = CompositionLibrary.templates.single.root;
      expect(restored.horizontalPadding, 28);
      expect(restored.verticalPadding, 6);
    },
  );
  testWidgets(
    'canvas exposes independent padding controls in the live preview',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [FlutterQuillLocalizations.delegate],
          home: CompositionCanvas(initialTemplate: template()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Horizontal padding: 8'), findsOneWidget);
      expect(find.text('Vertical padding: 8'), findsOneWidget);
      tester.widget<Slider>(find.byType(Slider).at(0)).onChanged!(24);
      await tester.pump();
      tester.widget<Slider>(find.byType(Slider).at(1)).onChanged!(12);
      await tester.pump();
      final root = tester
          .widget<CompositionPreview>(find.byType(CompositionPreview))
          .template
          .root;
      expect(root.horizontalPadding, 24);
      expect(root.verticalPadding, 12);
      // The actual page renderer receives the same independent insets.
      expect(
        find.descendant(
          of: find.byType(CompositionPreview),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.padding ==
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(CompositionLibrary.templates.single.root.horizontalPadding, 24);
      expect(CompositionLibrary.templates.single.root.verticalPadding, 12);
      expect(tester.takeException(), isNull);
    },
  );
  test('library survives reload with layout and styles', () async {
    final original = template();
    await CompositionLibrary.save(original);
    CompositionLibrary.templates.clear();
    await CompositionLibrary.load();
    expect(CompositionLibrary.templates.single.toJson(), original.toJson());
  });
  test('snapshot carries content and refers to the saved layout', () async {
    final saved = template();
    await CompositionLibrary.save(saved);
    final component = ComposedComponent(
      'source',
      CompositionTemplate.fromJson(saved.toJson()),
    );
    final text =
        component.state.leaves.values.last.component.state
            as TextComponentState;
    text.controller.document.insert(0, 'Preserve this content');
    final json = jsonDecode(
      jsonEncode(
        ComponentSnapshot.capture(ComponentBox(component: component)).toJson(),
      ),
    ) as Map<String, dynamic>;
    expect(jsonEncode(json), isNot(contains('horizontalPadding')));
    expect((json['extra'] as Map).containsKey('template'), isFalse);
    final copy = ComponentSnapshot.fromJson(json).instantiate();
    final restored = copy.component as ComposedComponent;
    expect(restored.state.template.root.focusBar, isTrue);
    expect(
      restored.state.leaves.values.last.component.output,
      'Preserve this content\n',
    );
    expect(restored.state.template.root.children.last.percent, 70);
    expect(restored.id, isNot(component.id));
    component.dispose();
    copy.dispose();
  });
  testWidgets('search finds composed components while Inbuilt is selected', (
    tester,
  ) async {
    await CompositionLibrary.save(template());
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AddComponentMenu(
            title: 'Components',
            onSelected: (v) => selected = v,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'callout');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Callout'));
    expect(selected, 'composed:example');
  });
  testWidgets('nested row and column render editable children', (tester) async {
    final document = DocumentSettingsController();
    final theme = PageSettingsController(document);
    final component = ComposedComponent(
      'nested',
      CompositionTemplate(
        'nested',
        'Nested',
        CompositionNode(
          'column',
          children: [
            CompositionNode(
              'row',
              children: [
                CompositionNode('text', percent: 60),
                CompositionNode('text', percent: 40),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        home: Scaffold(
          body: component.buildUI(
            theme: theme,
            componentState: component.state,
            isSelected: true,
            onSelect: () {},
            onCreateBelow: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(QuillEditor), findsNWidgets(2));
    for (final editor in tester.widgetList<QuillEditor>(
      find.byType(QuillEditor),
    )) {
      expect(editor.config.placeholder, 'Text');
      expect(editor.focusNode.hasFocus, isFalse);
    }
    await tester.pumpWidget(const SizedBox());
    component.dispose();
    theme.dispose();
    document.dispose();
  });
  for (final direction in ['column', 'row']) {
    testWidgets(
      '$direction grows with nested text and shrinks to its minimum',
      (tester) async {
        final document = DocumentSettingsController();
        final theme = PageSettingsController(document);
        final component = ComposedComponent(
          'growing',
          CompositionTemplate(
            'growing',
            'Growing',
            CompositionNode(
              direction,
              height: 320,
              children: [
                CompositionNode(
                  'column',
                  percent: 60,
                  children: [CompositionNode('text')],
                ),
                CompositionNode('text', percent: 40),
              ],
            ),
          ),
        );
        final key = GlobalKey();
        final text =
            component.state.leaves.values.first.component.state
                as TextComponentState;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [FlutterQuillLocalizations.delegate],
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  key: key,
                  child: component.buildUI(
                    theme: theme,
                    componentState: component.state,
                    isSelected: true,
                    onSelect: () {},
                    onCreateBelow: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byKey(key)).height, closeTo(320, 0.1));
        text.replaceDocument(
          Document.fromJson([
            {'insert': "${List.generate(60, (i) => 'Line $i').join('\n')}\n"},
          ]),
        );
        await tester.pumpAndSettle();
        final grown = tester.getRect(find.byKey(key));
        expect(grown.height, greaterThan(320));
        final editor = find.byWidgetPredicate(
          (w) => w is QuillEditor && w.focusNode == text.focusNode,
        );
        expect(tester.getRect(editor).bottom, lessThanOrEqualTo(grown.bottom));
        // The page owns scrolling; leaves must expose all their content.
        expect(
          find.descendant(
            of: find.byKey(key),
            matching: find.byType(SingleChildScrollView),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        text.replaceDocument(Document());
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byKey(key)).height, closeTo(320, 0.1));
        await tester.pumpWidget(const SizedBox());
        component.dispose();
        theme.dispose();
        document.dispose();
      },
    );
  }
  testWidgets(
    'canvas preview accepts text and preserves it through layout changes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [FlutterQuillLocalizations.delegate],
          home: CompositionCanvas(initialTemplate: template()),
        ),
      );
      await tester.pumpAndSettle();
      final preview = find.byType(CompositionPreview);
      expect(find.text('Live preview'), findsOneWidget);
      final editors = find.descendant(
        of: preview,
        matching: find.byType(QuillEditor),
      );
      expect(editors, findsNWidgets(2));
      await tester.ensureVisible(editors.first);
      await tester.tapAt(tester.getCenter(editors.first));
      await tester.pumpAndSettle();
      final editor = tester.widget<QuillEditor>(editors.first);
      expect(editor.focusNode.hasFocus, isTrue);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Preview content\n',
          selection: TextSelection.collapsed(offset: 15),
        ),
      );
      await tester.pumpAndSettle();
      expect(editor.controller.document.toPlainText(), 'Preview content\n');
      // Change the selected root's focus-bar style; the preview updates live.
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(
        tester.widget<QuillEditor>(editors.first).controller,
        same(editor.controller),
      );
      expect(editor.controller.document.toPlainText(), 'Preview content\n');
      await tester.ensureVisible(editors.last);
      await tester.tapAt(tester.getCenter(editors.last));
      await tester.pumpAndSettle();
      expect(editor.focusNode.hasFocus, isFalse);
      expect(
        tester.widget<QuillEditor>(editors.last).focusNode.hasFocus,
        isTrue,
      );
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(
        jsonEncode(CompositionLibrary.templates.single.toJson()),
        isNot(contains('Preview content')),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'preview exposes page image controls and retains images when layout changes',
    (tester) async {
      final root = CompositionNode(
        'column',
        children: [CompositionNode('image')],
      );
      Widget view() => MaterialApp(
        localizationsDelegates: const [FlutterQuillLocalizations.delegate],
        home: Scaffold(
          body: SingleChildScrollView(
            child: CompositionPreview(
              template: CompositionTemplate(
                'preview',
                'Image',
                CompositionNode.fromJson(root.toJson()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(view());
      await tester.pumpAndSettle();
      expect(find.text('Choose image'), findsOneWidget);
      final imageView = tester.widget<ImageComponentView>(
        find.byType(ImageComponentView),
      );
      imageView.state.caption = 'Image caption';
      root.horizontalPadding = 24;
      root.children.add(CompositionNode('text'));
      await tester.pumpWidget(view());
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ImageComponentView>(find.byType(ImageComponentView))
            .state,
        same(imageView.state),
      );
      expect(imageView.state.caption, 'Image caption');
      expect(find.byType(QuillEditor), findsOneWidget);
      root.children.removeAt(0);
      await tester.pumpWidget(view());
      await tester.pumpAndSettle();
      expect(find.byType(ImageComponentView), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('dragging a wrapper adds it to the canvas', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [FlutterQuillLocalizations.delegate],
        home: CompositionCanvas(),
      ),
    );
    final from = tester.getCenter(find.text('Row'));
    final to = tester.getCenter(find.text('Drop components here'));
    await tester.dragFrom(from, to - from);
    await tester.pumpAndSettle();
    expect(find.text('ROW · 100%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('canvas adds a component and saves a named layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [FlutterQuillLocalizations.delegate],
        home: CompositionCanvas(),
      ),
    );
    await tester.enterText(find.byType(TextField), 'My callout');
    await tester.tap(find.text('Title'));
    await tester.pump();
    expect(find.text('TITLE · 100%'), findsOneWidget);
    await tester.tap(find.text('Save component'));
    await tester.pumpAndSettle();
    expect(CompositionLibrary.templates.single.name, 'My callout');
    expect(
      CompositionLibrary.templates.single.root.children.single.kind,
      'title',
    );
  });
}
