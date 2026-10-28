import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/editor_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/ui/sidebar/document_settings/document_information_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('document information can collapse and expand after text focus', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = DocumentSettingsController();
    final pageSettings = PageSettingsController(settings);
    final controller = EditorController(pageSettings, settings);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DocumentInformationSection(controller: controller),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byType(SelectableText).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Document Information'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Created date'), findsNothing);
      await tester.tap(find.text('Document Information'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Created date'), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    pageSettings.dispose();
    settings.dispose();
  });
}
