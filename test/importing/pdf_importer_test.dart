import 'package:booklet/importing/pdf_importer.dart';
import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/detail/editor/editor_vm.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('normalizes PDF text and skips empty pages', () {
    final result = PdfImporter.fromText([
      ' First\r\nsecond\rthird\u0000 ',
      '  ',
      'Last page',
    ], fileName: 'Report.PDF');
    expect(result.title, 'Report');
    expect(result.pages, ['First\nsecond\nthird', 'Last page']);
  });

  test('rejects PDFs with no extractable text', () {
    expect(
      () => PdfImporter.fromText(['', ' \r\n'], fileName: 'scan.pdf'),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'imports editable text without replacing pages and respects read only',
    () {
      final settings = DocumentSettingsController();
      final theme = PageSettingsController(settings);
      final vm = EditorVM(theme);
      addTearDown(() {
        vm.dispose();
        theme.dispose();
        settings.dispose();
      });
      final originalId = vm.selectedPage!.id;
      final result = PdfImporter.fromText([
        'Hello\nPDF',
        'Second page',
      ], fileName: 'Report.pdf');
      vm.importPdf(result);
      expect(vm.loadedPages.length, 2);
      expect(vm.selectedPage!.id, isNot(originalId));
      expect(vm.selectedPage!.title, 'Report');
      expect(vm.components.length, 2);
      expect(
        (vm.components.first.component.state as TextComponentState)
            .controller
            .document
            .toPlainText(),
        'Hello\nPDF\n',
      );
      settings.updateEditMode(DocumentEditMode.readOnly);
      vm.importPdf(result);
      expect(vm.loadedPages.length, 2);
    },
  );
}
