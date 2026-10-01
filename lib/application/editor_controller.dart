import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:booklet/application/asset_manager_controller.dart';
import 'package:booklet/application/component_clipboard_controller.dart';
import 'package:booklet/application/navigation_clipboard_controller.dart';
import 'package:booklet/business/page_content.dart';
import 'package:booklet/storage/booklet_file.dart';
import 'package:booklet/ui/base_vm.dart';
import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_snapshot.dart';
import 'package:booklet/ui/navigation/navigation_node.dart';

class EditorController extends ChangeNotifier {
  EditorController(
    this.editorTheme,
    this.documentSettingsController, {
    this.autoSaveDelay = const Duration(milliseconds: 750),
  }) : viewModel = BaseVM(editorTheme),
       assetManagerController = AssetManagerController() {
    viewModel.setDocumentChangedCallback(_scheduleAutoSave);
    assetManagerController.onDocumentChanged = markDocumentChanged;
  }

  final Duration autoSaveDelay;

  final PageSettingsController editorTheme;
  final DocumentSettingsController documentSettingsController;
  final BaseVM viewModel;
  final AssetManagerController assetManagerController;
  // Lives on the controller (not the per-page view model) so copied
  // components survive page switches and opening a different booklet.
  final ComponentClipboardController clipboardController =
      ComponentClipboardController();
  final NavigationClipboardController navigationClipboardController =
      NavigationClipboardController();
  final Map<String, String> _navigationPageSources = {};
  final Map<String, NavigationNode> _stagedNavigationSubtrees = {};
  Timer? _autoSaveTimer;
  Future<void>? _saveInProgress;
  String? _lastSavedSignature;
  String? _autoSaveError;
  bool _isAutoSaving = false;
  bool isLoadingPage = false;
  String? _documentPath;
  int _selectionRequest = 0;

  String? get documentPath => _documentPath;
  String? get autoSaveError => _autoSaveError;
  bool get isAutoSaving => _isAutoSaving;

  bool get canPasteComponents => !documentSettingsController.isReadOnly;

  void markDocumentChanged() {
    if (documentSettingsController.isReadOnly) return;
    _autoSaveError = null;
    _scheduleAutoSave();
  }

  void _scheduleAutoSave() {
    if (documentSettingsController.isReadOnly || _documentPath == null) {
      return;
    }
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(autoSaveDelay, () {
      unawaited(flushAutoSave());
    });
  }

  Future<void> flushAutoSave() async {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    final path = _documentPath;
    if (path == null || documentSettingsController.isReadOnly) return;

    final signature = _documentSignature();
    if (signature == _lastSavedSignature) return;

    _isAutoSaving = true;
    notifyListeners();
    try {
      await _persistToPath(path, sourcePackagePath: path);
      _lastSavedSignature = signature;
      _autoSaveError = null;
    } catch (error) {
      _autoSaveError = error.toString();
    } finally {
      _isAutoSaving = false;
      notifyListeners();
    }

    if (_documentSignature() != _lastSavedSignature) {
      _scheduleAutoSave();
    }
  }

  String _documentSignature() => jsonEncode({
    'navigation': viewModel.navigation.groups
        .map((node) => node.toJson())
        .toList(),
    'pages': [
      for (final page in viewModel.loadedPages)
        {
          'id': page.id,
          'title': page.title,
          'components': [
            for (final component in page.components)
              ComponentSnapshot.capture(component).toJson(),
          ],
        },
    ],
  });

  Future<void> copySelectedComponents() async {
    final snapshots = viewModel.captureSelectedComponents();
    if (snapshots.isEmpty) {
      return;
    }
    await clipboardController.copy(snapshots);
  }

  Future<List<ComponentBox>> pasteComponents() async {
    if (!canPasteComponents) {
      return const [];
    }
    final snapshots = await clipboardController.paste();
    if (snapshots.isEmpty) {
      return const [];
    }
    final pasted = viewModel.pasteComponents(snapshots);
    if (pasted.isNotEmpty) {
      notifyListeners();
    }
    return pasted;
  }

  Future<void> copySelectedNavigationNode() async {
    final node = viewModel.navigation.selectedNode;
    if (node == null) {
      return;
    }
    final bundle = await BookletFile.exportNavigationSubtree(
      packagePath: _documentPath,
      node: node,
      loadedPages: viewModel.loadedPages,
      theme: editorTheme,
    );
    await navigationClipboardController.copy(bundle);
  }

  Future<void> duplicateSelectedNavigationNode() async {
    if (documentSettingsController.isReadOnly) {
      return;
    }
    final source = viewModel.navigation.selectedNode;
    if (source == null) {
      return;
    }
    final bundle = await BookletFile.exportNavigationSubtree(
      packagePath: _documentPath,
      node: source,
      loadedPages: viewModel.loadedPages,
      theme: editorTheme,
    );
    final sourceNode = NavigationNode.fromJson(
      Map<String, dynamic>.from(bundle['node'] as Map),
    );
    final duplicate = viewModel.navigation.duplicateNode(source);
    if (duplicate == null) {
      return;
    }
    await _importNavigationNode(bundle, sourceNode, duplicate);
    markDocumentChanged();
    await _activateCopiedNode(duplicate);
  }

  Future<void> pasteSelectedNavigationNode() async {
    if (documentSettingsController.isReadOnly) {
      return;
    }
    final bundle = await navigationClipboardController.paste();
    final rawNode = bundle?['node'];
    if (bundle == null || rawNode is! Map) {
      return;
    }
    final sourceNode = NavigationNode.fromJson(
      Map<String, dynamic>.from(rawNode),
    );
    final copiedNode = viewModel.navigation.pasteNode(sourceNode);
    if (copiedNode == null) {
      return;
    }
    await _importNavigationNode(bundle, sourceNode, copiedNode);
    markDocumentChanged();
    await _activateCopiedNode(copiedNode);
  }

  Future<void> _importNavigationNode(
    Map<String, dynamic> bundle,
    NavigationNode sourceNode,
    NavigationNode copiedNode,
  ) async {
    final packagePath = _documentPath;
    if (packagePath != null) {
      await BookletFile.importNavigationSubtree(
        packagePath: packagePath,
        sourceNode: sourceNode,
        copiedNode: copiedNode,
        bundle: bundle,
        useAbsoluteAssetPaths: false,
      );
    } else {
      final stagedPackage = await Directory.systemTemp.createTemp(
        'booklet_navigation_paste',
      );
      await BookletFile.importNavigationSubtree(
        packagePath: stagedPackage.path,
        sourceNode: sourceNode,
        copiedNode: copiedNode,
        bundle: bundle,
        useAbsoluteAssetPaths: true,
      );
      _stagedNavigationSubtrees[stagedPackage.path] = copiedNode;
      for (final pageNode in _pageNodes(copiedNode)) {
        _navigationPageSources[pageNode.pageId!] = stagedPackage.path;
      }
    }
  }

  Future<void> _activateCopiedNode(NavigationNode node) async {
    if (node.isPage && node.pageId != null) {
      await selectPage(node.pageId!);
    } else if (node.isAssetsFolder) {
      selectNode(node);
    } else {
      notifyListeners();
    }
  }

  Iterable<NavigationNode> _pageNodes(NavigationNode node) sync* {
    if (node.isPage) {
      yield node;
    }
    for (final child in node.children) {
      yield* _pageNodes(child);
    }
  }

  bool get hasOpenedBooklet => _documentPath != null;
  PageContent? get selectedPage => viewModel.selectedPage;

  void createBooklet() {
    _autoSaveTimer?.cancel();
    _documentPath = null;
    _lastSavedSignature = null;
    notifyListeners();
  }

  Future<bool> openBooklet() async {
    final manifest = await BookletFile.openManifest();
    if (manifest == null) {
      return false;
    }
    await flushAutoSave();
    await _applyManifest(manifest);
    return true;
  }

  Future<bool> openBookletAtPath(String packagePath) async {
    await flushAutoSave();
    final manifest = await BookletFile.loadManifestAtPath(packagePath);
    await _applyManifest(manifest);
    return true;
  }

  Future<void> _applyManifest(BookletManifest manifest) async {
    _autoSaveTimer?.cancel();
    _lastSavedSignature = null;
    _documentPath = manifest.path;
    viewModel.replaceNavigation(
      manifest.groups,
      selectedPageId: manifest.selectedPageId,
      selectedAssetFolderId: manifest.selectedAssetFolderId,
    );
    assetManagerController.selectFolder(
      viewModel.navigation.selectedNode,
      _documentPath,
    );
    notifyListeners();

    final selectedFolderId = viewModel.navigation.selectedAssetFolderId;
    final pageId = selectedFolderId == null
        ? manifest.selectedPageId ?? _firstPageId(manifest.groups)
        : null;
    if (pageId != null) {
      await selectPage(pageId, saveCurrentPage: false);
    }
    _lastSavedSignature = _documentSignature();
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

    final pagePackagePath = _navigationPageSources[pageId] ?? _documentPath;
    if (pagePackagePath == null) {
      isLoadingPage = false;
      notifyListeners();
      return;
    }

    final page = await BookletFile.loadPage(
      pagePackagePath,
      pageId,
      editorTheme,
    );
    if (request != _selectionRequest) {
      page.dispose();
      return;
    }

    viewModel.setSelectedPage(
      page,
      preserveLoadedPages:
          _documentPath == null && _navigationPageSources.containsKey(pageId),
    );
    isLoadingPage = false;
    notifyListeners();
  }

  void selectNode(NavigationNode node) {
    if (node.isPage && node.pageId != null) {
      assetManagerController.selectFolder(null, _documentPath);
      selectPage(node.pageId!);
      return;
    }
    ++_selectionRequest;
    isLoadingPage = false;
    viewModel.selectNode(node);
    assetManagerController.selectFolder(
      node.isAssetsFolder ? node : null,
      _documentPath,
    );
    notifyListeners();
  }

  void addAssetsFolder() {
    final folder = viewModel.addAssetsFolder();
    assetManagerController.selectFolder(folder, _documentPath);
    notifyListeners();
  }

  void deleteSelectedNode() {
    final removedNode = viewModel.deleteSelectedNode();
    if (removedNode == null) {
      return;
    }
    assetManagerController.selectFolder(
      viewModel.navigation.selectedNode,
      _documentPath,
    );
    unawaited(BookletFile.deleteAssetsForNode(_documentPath, removedNode));
    notifyListeners();
  }

  Future<bool> saveBooklet() => _save(saveAs: false);

  Future<bool> saveBookletAs() => _save(saveAs: true);

  Future<bool> _save({required bool saveAs}) async {
    final previousPath = _documentPath;
    var path = saveAs ? null : _documentPath;
    path ??= await BookletFile.chooseSavePath();
    if (path == null) {
      return false;
    }

    _documentPath = path;
    _autoSaveTimer?.cancel();
    await _persistToPath(path, sourcePackagePath: previousPath);
    _lastSavedSignature = _documentSignature();
    _autoSaveError = null;
    assetManagerController.selectFolder(
      viewModel.navigation.selectedNode,
      path,
    );
    notifyListeners();
    return true;
  }

  Future<void> _persistToPath(
    String path, {
    required String? sourcePackagePath,
  }) async {
    final activeSave = _saveInProgress;
    if (activeSave != null) {
      await activeSave;
      return _persistToPath(path, sourcePackagePath: sourcePackagePath);
    }

    final completion = Completer<void>();
    _saveInProgress = completion.future;
    try {
      for (final entry in _stagedNavigationSubtrees.entries) {
        await BookletFile.copyStagedNavigationPages(
          path,
          entry.key,
          entry.value,
        );
      }
      await _saveLoadedPages();
      await BookletFile.saveManifest(
        packagePath: path,
        groups: viewModel.navigation.groups,
        selectedPageId: viewModel.selectedPageId,
        selectedAssetFolderId: viewModel.navigation.selectedAssetFolderId,
        sourcePackagePath: sourcePackagePath,
      );
      for (final stagedPath in _stagedNavigationSubtrees.keys) {
        await Directory(stagedPath).delete(recursive: true);
      }
      _stagedNavigationSubtrees.clear();
      _navigationPageSources.clear();
      assetManagerController.selectFolder(
        viewModel.navigation.selectedNode,
        path,
      );
    } finally {
      completion.complete();
      _saveInProgress = null;
    }
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
    _autoSaveTimer?.cancel();
    assetManagerController.dispose();
    viewModel.dispose();
    super.dispose();
  }
}
