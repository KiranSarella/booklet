import 'dart:io';

import 'package:archive/archive.dart';
import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/editor_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final extension in ['docx', 'txt']) {
    test(
      '$extension imports an editable page and respects read-only mode',
      () async {
        final temp = await Directory.systemTemp.createTemp('document_import_');
        final settings = DocumentSettingsController();
        final theme = PageSettingsController(settings);
        final controller = EditorController(theme, settings);
        addTearDown(() async {
          controller.dispose();
          theme.dispose();
          settings.dispose();
          await temp.delete(recursive: true);
        });
        final file = File('${temp.path}/Report.$extension');
        if (extension == 'docx') {
          final archive = Archive()
            ..addFile(
              ArchiveFile.string(
                'word/document.xml',
                '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>Hello</w:t></w:r></w:p></w:body></w:document>',
              ),
            );
          await file.writeAsBytes(ZipEncoder().encode(archive));
        } else {
          await file.writeAsString('Hello');
        }
        final vm = controller.viewModel;
        final original = vm.selectedPage!.id;
        final importFile = extension == 'docx'
            ? controller.importDocx
            : controller.importTxt;
        await importFile(file.path);
        expect(vm.loadedPages.length, 2);
        expect(vm.selectedPage!.id, isNot(original));
        expect(vm.selectedPage!.title, 'Report');
        expect(
          (vm.components.single.component.state as TextComponentState)
              .controller
              .document
              .toPlainText(),
          'Hello\n',
        );
        settings.updateEditMode(DocumentEditMode.readOnly);
        await importFile(file.path);
        expect(vm.loadedPages.length, 2);
      },
    );
  }
}
