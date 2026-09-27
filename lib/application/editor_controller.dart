import 'package:flutter/foundation.dart';
import 'package:booklet/business/page_content.dart';
import 'package:booklet/storage/booklet_file.dart';
import 'package:booklet/ui/base_vm.dart';
import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/ui/navigation/navigation_node.dart';

class EditorController extends ChangeNotifier {
  EditorController(this.editorTheme, this.documentSettingsController)
    : viewModel = BaseVM(editorTheme);

  final PageSettingsController editorTheme;
  final DocumentSettingsController documentSettingsController;
  final BaseVM viewModel;
  bool isLoadingPage = false;
  String? _documentPath;
  int _selectionRequest = 0;

  String? get documentPath => _documentPath;
  bool get hasOpenedBooklet => _documentPath != null;
  PageContent? get selectedPage => viewModel.selectedPage;

  void createBooklet() {
    _documentPath = null;
    notifyListeners();
  }

  Future<bool> openBooklet() async {
    final manifest = await BookletFile.openManifest();
    if (manifest == null) {
      return false;
    }

    _documentPath = manifest.path;
    viewModel.replaceNavigation(
      manifest.groups,
      selectedPageId: manifest.selectedPageId,
    );
    notifyListeners();

    final pageId = manifest.selectedPageId ?? _firstPageId(manifest.groups);
    if (pageId != null) {
      await selectPage(pageId, saveCurrentPage: false);
    }
    return true;
  }

  Future<void> selectPage(String pageId, {bool saveCurrentPage = true}) async {
    if (viewModel.selectedPageId == pageId && viewModel.selectedPage != null) {
      return;
    }

    if (saveCurrentPage) {
      await _saveLoadedPages();
    }

    final request = ++_selectionRequest;
    isLoadingPage = true;
    viewModel.selectPage(pageId);
    notifyListeners();

    if (_documentPath == null) {
      isLoadingPage = false;
      notifyListeners();
      return;
    }

    final page = await BookletFile.loadPage(
      _documentPath!,
      pageId,
      editorTheme,
    );
    if (request != _selectionRequest) {
      page.dispose();
      return;
    }

    viewModel.setSelectedPage(page);
    isLoadingPage = false;
    notifyListeners();
  }

  void selectNode(NavigationNode node) {
    if (node.isPage && node.pageId != null) {
      selectPage(node.pageId!);
      return;
    }
    viewModel.selectNode(node);
    notifyListeners();
  }

  Future<bool> saveBooklet() => _save(saveAs: false);

  Future<bool> saveBookletAs() => _save(saveAs: true);

  Future<bool> _save({required bool saveAs}) async {
    var path = saveAs ? null : _documentPath;
    path ??= await BookletFile.chooseSavePath();
    if (path == null) {
      return false;
    }

    _documentPath = path;
    await _saveLoadedPages();
    await BookletFile.saveManifest(
      packagePath: path,
      groups: viewModel.navigation.groups,
      selectedPageId: viewModel.selectedPageId,
    );
    notifyListeners();
    return true;
  }

  Future<void> _saveLoadedPages() async {
    final path = _documentPath;
    if (path == null) {
      return;
    }
    for (final page in viewModel.loadedPages) {
      await BookletFile.savePage(path, page);
    }
  }

  String? _firstPageId(List<NavigationNode> nodes) {
    for (final node in nodes) {
      if (node.isPage && node.pageId != null) {
        return node.pageId;
      }
      final childPageId = _firstPageId(node.children);
      if (childPageId != null) {
        return childPageId;
      }
    }
    return null;
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }
}
