import 'package:booklet/ui/components/component.dart';
import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_snapshot.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/icon_component.dart';
import 'package:booklet/ui/components/inbuilt_components/inbuilt_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('narrow composition columns expose upload in an options dialog', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final document = DocumentSettingsController();
    final theme = PageSettingsController(document);
    final state = IconComponentState();
    var parentSelected = false;
    late StateSetter updateSelection;
    await tester.pumpWidget(
      StatefulBuilder(builder: (context, setState) {
        updateSelection = setState;
        return ComposedSelectionScope(isSelected: parentSelected, child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 80,
            child: IconComponentView(
              state: state,
              theme: theme,
              isSelected: false,
              onSelect: () {},
            ),
          ),
        ),
      ));
      }),
    );
    expect(find.byTooltip('Icon options'), findsNothing);
    updateSelection(() => parentSelected = true);
    await tester.pump();
    expect(find.byTooltip('Icon options'), findsOneWidget);
    expect(find.text('Upload'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Icon options'));
    await tester.pumpAndSettle();
    expect(find.text('Upload'), findsOneWidget);
    expect(find.text('Tint color'), findsOneWidget);
    expect(find.byType(DropdownButton<IconSize>), findsOneWidget);
    await tester.tap(find.byTooltip('Enable border'));
    await tester.pumpAndSettle();
    expect(state.borderEnabled, isTrue);
    expect(find.byTooltip('Disable border'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    updateSelection(() => parentSelected = false);
    await tester.pump();
    expect(find.byTooltip('Icon options'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
    theme.dispose();
    document.dispose();
  });

  testWidgets(
    'edit controls stay beside the left aligned icon without a caption',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final document = DocumentSettingsController();
      final theme = PageSettingsController(document);
      final state = IconComponentState();
      var selections = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              child: IconComponentView(
                state: state,
                theme: theme,
                isSelected: true,
                onSelect: () => selections++,
              ),
            ),
          ),
        ),
      );
      final upload = find.byTooltip('Icon');
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Upload'), findsOneWidget);
      await tester.tap(upload);
      await tester.pump();
      expect(selections, 1);
      expect(tester.takeException(), isNull);
      state.setIcon(
        Uint8List.fromList(
          utf8.encode(
            '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><rect width="32" height="32"/></svg>',
          ),
        ),
        'svg',
      );
      await tester.pumpAndSettle();
      await tester.tap(upload);
      await tester.pump();
      expect(selections, 2);
      expect(find.widgetWithText(TextButton, 'Upload'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(tester.getTopLeft(upload).dx, 14);
      expect(tester.getSize(upload), const Size(64, 64));
      expect(
        tester.getTopLeft(find.byType(DropdownButton<IconShape>)).dx,
        greaterThan(tester.getTopRight(upload).dx),
      );
      expect(find.byTooltip('Remove icon'), findsNothing);
      expect(find.byType(Slider), findsNothing);
      await tester.tap(find.byTooltip('Enable border'));
      await tester.pump();
      expect(state.borderEnabled, isTrue);
      expect(state.borderColor, Colors.grey);
      state.setTint(Colors.blue);
      state.setSize(IconSize.small);
      await tester.pump();
      expect(state.borderColor, Colors.blue);
      expect(tester.getSize(upload), const Size(32, 32));
      await tester.tap(find.byTooltip('Disable border'));
      await tester.pump();
      expect(state.borderEnabled, isFalse);
      expect(find.text('Tint color'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.byType(DropdownButton<IconSize>));
      await tester.pumpAndSettle();
      for (final label in ['32×32', '64×64', '96×96', '128×128']) {
        expect(find.text(label), findsWidgets);
      }
      await tester.tap(find.text('128×128').last);
      await tester.pumpAndSettle();
      expect(state.size, IconSize.extraLarge);
      expect(tester.getSize(upload), const Size(128, 128));
      for (var i = 0; i < 7; i++) {
        theme.increaseFontSize();
      }
      await tester.pump();
      expect(tester.getSize(upload), const Size(256, 256));
      expect(state.size, IconSize.extraLarge);
      theme.resetFontSize();
      await tester.pump();
      expect(tester.getSize(upload), const Size(128, 128));
      theme.decreaseFontSize();
      await tester.pump();
      expect(tester.getSize(upload).width, closeTo(128 * 12 / 14, 0.001));
      theme.resetFontSize();
      await tester.pump();
      await tester.tap(find.byType(DropdownButton<IconImageFit>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fill').last);
      await tester.pumpAndSettle();
      expect(state.imageFit, IconImageFit.fill);
      expect(state.boxFit, BoxFit.cover);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
      theme.dispose();
      document.dispose();
    },
  );

  test(
    'icon clipboard preserves embedded SVG and appearance independently',
    () {
      final original = InbuiltComponents.prepareCompoent('original', 'icon');
      final state = original.state as IconComponentState;
      final bytes = Uint8List.fromList(
        utf8.encode('<svg xmlns="http://www.w3.org/2000/svg"/>'),
      );
      state.setIcon(bytes, 'svg');
      state.setShape(IconShape.circle);
      state.setTint(Colors.red);
      state.setBorderEnabled(true);
      state.setSize(IconSize.small);
      state.setImageFit(IconImageFit.fill);
      final box = ComponentBox(component: original);
      final snapshot = ComponentSnapshot.fromJson(
        jsonDecode(jsonEncode(ComponentSnapshot.capture(box).toJson()))
            as Map<String, dynamic>,
      );
      final copy = snapshot.instantiate(id: 'copy');
      final restored = copy.component.state as IconComponentState;
      expect(restored.bytes, bytes);
      expect(restored.extension, 'svg');
      expect(restored.shape, IconShape.circle);
      expect(restored.tint?.toARGB32(), Colors.red.toARGB32());
      expect(restored.borderEnabled, isTrue);
      expect(restored.size, IconSize.small);
      expect(restored.imageFit, IconImageFit.fill);
      expect(restored.boxFit, BoxFit.cover);
      state.removeIcon();
      expect(restored.bytes, bytes);
      original.dispose();
      copy.component.dispose();
    },
  );

  test(
    'legacy borders are restored as toggles and missing styles use defaults',
    () {
      final state = IconComponentState();
      state.restore({'borderWidth': 99});
      expect(state.borderEnabled, isTrue);
      expect(state.size, IconSize.medium);
      expect(state.imageFit, IconImageFit.fit);
      expect(state.shape, IconShape.corners);
      expect(state.tint, isNull);
      state.restore({'borderWidth': -2});
      expect(state.borderEnabled, isFalse);
      state.dispose();
    },
  );

  test('extracts PNG from modern ICNS and rejects broken chunk lengths', () {
    final png = [137, 80, 78, 71, 13, 10, 26, 10, 0];
    final bytes = Uint8List.fromList([
      ...ascii.encode('icns'),
      0,
      0,
      0,
      25,
      ...ascii.encode('ic07'),
      0,
      0,
      0,
      17,
      ...png,
    ]);
    expect(decodeIcnsPng(bytes), png);
    bytes[15] = 100;
    expect(decodeIcnsPng(bytes), isNull);
  });
}
