import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/importing/html_importer.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/components/component_snapshot.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/code_block_component.dart';
import 'package:booklet/ui/detail/editor/editor_vm.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('imports and selects a new editable page without replacing existing content', () {
    final settings = DocumentSettingsController();
    final theme = PageSettingsController(settings);
    final vm = EditorVM(theme);
    addTearDown(() {
      vm.dispose();
      theme.dispose();
      settings.dispose();
    });
    final originalId = vm.selectedPage!.id;
    final result = HtmlImporter.parse('''<article><h1>Guide</h1>
      <p><strong>Formatted</strong> text</p><ol start="4"><li>Fourth</li></ol>
      <pre class="language-python">print("hello")</pre><blockquote><p>Quote</p></blockquote>
      <img src="image.png"><video src="https://example.com/movie.mp4"></video>
      </article>''', baseUri: Uri.file('/tmp/docs/index.html'));
    vm.importHtml(result);
    expect(vm.loadedPages.length, 2);
    expect(vm.selectedPage!.id, isNot(originalId));
    expect(vm.selectedPage!.title, 'Guide');
    expect(vm.components.length, 7);
    expect(
      (vm.components[1].component.state as TextComponentState)
          .controller
          .document
          .toDelta()
          .toJson(),
      contains(
        equals({
          'insert': 'Formatted',
          'attributes': {'bold': true},
        }),
      ),
    );
    expect(
      (vm.components[2].component.state as NumberedListComponentState)
          .sequenceNumber,
      4,
    );
    final code = vm.components[3].component.state as CodeBlockComponentState;
    expect(code.controller.text, 'print("hello")');
    expect(code.languageId, 'python');
    expect(vm.components[4].hasFocusBar, isTrue);
    expect(
      (vm.components[5].component.state as ImageComponentState).mediaPath,
      '/tmp/docs/image.png',
    );
    final snapshot = ComponentSnapshot.capture(vm.components[6]).instantiate();
    expect(
      (snapshot.component.state as VideoComponentState).mediaPath,
      'https://example.com/movie.mp4',
    );
    snapshot.dispose();
    settings.updateEditMode(DocumentEditMode.readOnly);
    vm.importHtml(result);
    expect(vm.loadedPages.length, 2);
  });
}
