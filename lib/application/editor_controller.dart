import 'package:booklet/ui/detail/editor/editor_search.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show FocusManager;
import 'package:booklet/application/asset_manager_controller.dart';
import 'package:booklet/application/component_clipboard_controller.dart';
import 'package:booklet/application/navigation_clipboard_controller.dart';
import 'package:booklet/business/page_content.dart';
import 'package:booklet/storage/booklet_file.dart';
import 'package:booklet/storage/deleted_items.dart';
import 'package:booklet/storage/daily_snapshots.dart';
import 'package:booklet/ui/detail/editor/editor_vm.dart';
import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_snapshot.dart';
import 'package:booklet/ui/sidebar/pages_navigation/navigation_node.dart';
import 'package:booklet/ui/sidebar/pages_navigation/pages_navigation_vm.dart';
import 'package:file_selector/file_selector.dart';

class EditorController extends ChangeNotifier {
  EditorController(
    this.editorTheme,
    this.documentSettingsController, {
    this.autoSaveDelay = const Duration(milliseconds: 750),
  }) : viewModel = EditorVM(editorTheme),
       assetManagerController = AssetManagerController() {
    viewModel.setDocumentChangedCallback(_scheduleAutoSave);
    viewModel.onHistoryChanged = notifyListeners;
    assetManagerController.onDocumentChanged = markDocumentChanged;
    _trashExpiryTimer = Timer.periodic(const Duration(hours: 1), (_) {
      if (!trashBusy && !snapshotsBusy) {
        unawaited(
          refreshDeletedItems().catchError((Object error) {
            trashError = error.toString();
            notifyListeners();
          }),
        );
      }
    });
  }

  final Duration autoSaveDelay;

  final PageSettingsController editorTheme;
  final DocumentSettingsController documentSettingsController;
  final EditorVM viewModel;
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
  Timer? _trashExpiryTimer;
  String? _unsavedTrashPackage;
  bool trashBusy = false;
  String? trashError;
  List<DeletedItem> deletedItems = [];
  String? get _trashPackage => _documentPath ?? _unsavedTrashPackage;

  Future<void> refreshDeletedItems() async {
    final package = _trashPackage;
    deletedItems = package == null ? [] : await DeletedItems.list(package);
    notifyListeners();
  }

  Future<void> _trashAction(Future<void> Function() action) async {
    if (trashBusy || snapshotsBusy || documentSettingsController.isReadOnly) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    trashBusy = true;
    trashError = null;
    notifyListeners();
    try {
      await action();
    } catch (error) {
      trashError = error.toString();
    } finally {
      try {
        await refreshDeletedItems();
      } catch (error) {
        trashError = error.toString();
      }
      trashBusy = false;
      notifyListeners();
    }
  }

  Future<void> permanentlyDeleteItem(String id) => _trashAction(() async {
    final package = _trashPackage;
    if (package != null) await DeletedItems.delete(package, id);
  });

  Future<void> restoreDeletedItem(String id) => _trashAction(() async {
    final package = _trashPackage;
    if (package == null) return;
    final bundle = await DeletedItems.read(package, id);
    final source = NavigationNode.fromJson(
      Map<String, dynamic>.from(bundle['node'] as Map),
    );
    // Use the navigation copy implementation to assign fresh IDs throughout.
    final restored = PagesNavigationVM().pasteNode(source)!;
    void rename(NavigationNode node) {
      if (node.isPage || node.isGroup) node.title = '${node.title} (restored)';
      for (final child in node.children) {
        rename(child);
      }
    }

    rename(restored);
    await _importNavigationNode(bundle, source, restored);
    viewModel.navigation.groups.add(restored);
    viewModel.navigation.selectNode(restored);
    markDocumentChanged();
    await flushAutoSave();
    if (_autoSaveError != null) {
      throw StateError(
        'Could not save restored item. The trash copy has been kept.',
      );
    }
    await DeletedItems.delete(package, id);
    await _activateCopiedNode(restored);
  });
  Future<void>? _saveInProgress;
  String? _lastSavedSignature;
  String? _autoSaveError;
  bool _isAutoSaving = false;
  bool isLoadingPage = false;
  String? _documentPath;
  int _selectionRequest = 0;

  String? _snapshotPackage;
  String? restoredSnapshotDay;
  String? lastRestoredSnapshotDay;
  List<DailySnapshot> dailySnapshots = [];
  bool snapshotsBusy = false;
  String? snapshotError;
  bool get examiningSnapshot => restoredSnapshotDay != null;
  String? get snapshotPackage => _snapshotPackage ?? _documentPath;

  Future<void> refreshSnapshots() async {
    final package = snapshotPackage;
    lastRestoredSnapshotDay = package == null
        ? null
        : await DailySnapshots.lastRestoredDay(package);
    dailySnapshots = package == null ? [] : await DailySnapshots.list(package);
    notifyListeners();
  }

  Future<void> _snapshotAction(Future<void> Function() action) async {
    if (snapshotsBusy || trashBusy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    ++_selectionRequest;
    snapshotsBusy = true;
    snapshotError = null;
    notifyListeners();
    try {
      await action();
      await refreshSnapshots();
    } catch (error) {
      snapshotError = error.toString();
    } finally {
      snapshotsBusy = false;
      notifyListeners();
    }
  }

  Future<void> restoreDailySnapshot(String day) => _snapshotAction(() async {
    final package = snapshotPackage;
    if (package == null ||
        examiningSnapshot ||
        documentSettingsController.isReadOnly) {
      return;
    }
    await flushAutoSave();
    if (_autoSaveError != null) {
      throw StateError(
        'Save failed. Your current changes must be saved before restoring.',
      );
    }
    await DailySnapshots.examine(package, day);
    _snapshotPackage = package;
    restoredSnapshotDay = day;
    await _applyManifest(
      await BookletFile.loadManifestAtPath(DailySnapshots.working(package)),
    );
  });

  Future<void> discardRestoredChanges() => _snapshotAction(() async {
    final package = _snapshotPackage;
    if (package == null) return;
    _autoSaveTimer?.cancel();
    if (_saveInProgress != null) await _saveInProgress;
    await _applyManifest(await BookletFile.loadManifestAtPath(package));
    _snapshotPackage = null;
    restoredSnapshotDay = null;
    await DailySnapshots.discard(package);
  });

  Future<void> keepRestoredChanges() => _snapshotAction(() async {
    final package = _snapshotPackage;
    if (package == null || documentSettingsController.isReadOnly) return;
    await flushAutoSave();
    if (_autoSaveError != null) {
      throw StateError('Save failed. Try again before keeping this version.');
    }
    await DailySnapshots.keep(package);
    _snapshotPackage = null;
    restoredSnapshotDay = null;
    await _applyManifest(await BookletFile.loadManifestAtPath(package));
  });

  Future<void> deleteDailySnapshot(String day) => _snapshotAction(() async {
    final package = snapshotPackage;
    if (package == null || examiningSnapshot) return;
    await DailySnapshots.delete(package, day);
  });

  Future<void> clearDailySnapshots() => _snapshotAction(() async {
    final package = snapshotPackage;
    if (package == null || examiningSnapshot) return;
    for (final entry in await DailySnapshots.list(package)) {
      await DailySnapshots.delete(package, entry.day);
    }
  });

  String? get documentPath => _documentPath;
  String? get autoSaveError => _autoSaveError;
  bool get isAutoSaving => _isAutoSaving;

  bool get canPasteComponents => !documentSettingsController.isReadOnly;

  Future<void> importMarkdown() async {
    if (documentSettingsController.isReadOnly) return;
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Markdown', extensions: ['md', 'markdown', 'mdown']),
      ],
    );
    if (file == null) return;
    final markdown = await File(file.path).readAsString();
    viewModel.importMarkdown(markdown, fileName: file.name);
    notifyListeners();
  }

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
    if (examiningSnapshot) return;
    dailySnapshots = [];
    deletedItems = [];
    trashError = null;
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
    await _openWithSnapshots(manifest);
    return true;
  }

  Future<bool> openBookletAtPath(String packagePath) async {
    await flushAutoSave();
    final manifest = await BookletFile.loadManifestAtPath(packagePath);
    await _openWithSnapshots(manifest);
    return true;
  }

  Future<void> _openWithSnapshots(BookletManifest manifest) async {
    final pendingTrash = _unsavedTrashPackage;
    _unsavedTrashPackage = null;
    if (pendingTrash != null) {
      await Directory(pendingTrash).delete(recursive: true);
    }
    _snapshotPackage = null;
    restoredSnapshotDay = null;
    await DailySnapshots.recover(manifest.path);
    await DailySnapshots.rollDay(manifest.path);
    final active = await DailySnapshots.activeDay(manifest.path);
    if (active != null) {
      _snapshotPackage = manifest.path;
      restoredSnapshotDay = active;
      await _applyManifest(
        await BookletFile.loadManifestAtPath(
          DailySnapshots.working(manifest.path),
        ),
      );
    } else {
      await _applyManifest(await BookletFile.loadManifestAtPath(manifest.path));
    }
    await refreshSnapshots();
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
    await refreshDeletedItems();
  }

  /// Searches loaded content first, including edits not yet saved to disk.
  Future<List<BookletSearchPage>> searchBooklet(
    String query, {
    bool caseSensitive = false,
  }) async {
    if (query.isEmpty) return [];
    final roots = viewModel.navigation.groups.toList();
    final package = _documentPath;
    final sources = Map<String, String>.of(_navigationPageSources);
    final results = <BookletSearchPage>[];
    Future<void> visit(NavigationNode node, List<String> ancestors) async {
      if (node.isPage && node.pageId != null) {
        final id = node.pageId!;
        var page = viewModel.loadedPages.where((p) => p.id == id).firstOrNull;
        final temporary = page == null;
        final source = sources[id] ?? package;
        if (page == null && source != null) {
          page = await BookletFile.loadPage(source, id, editorTheme);
        }
        try {
          final matches = page == null
              ? <EditorSearchMatch>[]
              : findEditorMatches(
                  page.components,
                  query,
                  caseSensitive: caseSensitive,
                );
          final titleMatch = caseSensitive
              ? node.title.contains(query)
              : node.title.toLowerCase().contains(query.toLowerCase());
          if (matches.isNotEmpty || titleMatch) {
            results.add(
              BookletSearchPage(id, node.title, ancestors.join(' › '), [
                for (final match in matches)
                  BookletSearchHit(match.text, match.start, match.end),
              ]),
            );
          }
        } finally {
          if (temporary) page?.dispose();
        }
      }
      for (final child in node.children.toList()) {
        await visit(child, [...ancestors, node.title]);
      }
    }

    for (final root in roots) {
      await visit(root, []);
    }
    return results;
  }

  /// Replaces content matches only; navigation titles are left intact.
  Future<int> replaceBookletMatches(
    String query,
    String replacement, {
    bool caseSensitive = false,
    bool all = false,
  }) async {
    if (query.isEmpty || documentSettingsController.isReadOnly) return 0;
    final results = await searchBooklet(query, caseSensitive: caseSensitive);
    var count = 0;
    for (final result in results.where((page) => page.hits.isNotEmpty)) {
      if (documentSettingsController.isReadOnly) break;
      final id = result.pageId;
      if (id == viewModel.selectedPageId) {
        count += viewModel.replaceSearchMatches(
          query,
          replacement,
          caseSensitive: caseSensitive,
          matchIndex: all ? null : 0,
        );
      } else {
        var page = viewModel.loadedPages
            .where((page) => page.id == id)
            .firstOrNull;
        final temporary = page == null;
        final source = _navigationPageSources[id] ?? _documentPath;
        if (page == null && source != null) {
          page = await BookletFile.loadPage(source, id, editorTheme);
        }
        if (page == null) continue;
        try {
          final matches = findEditorMatches(
            page.components,
            query,
            caseSensitive: caseSensitive,
          );
          final selected = all ? matches : matches.take(1).toList();
          if (temporary &&
              source != null &&
              selected.isNotEmpty &&
              !examiningSnapshot) {
            await DailySnapshots.rollDay(source);
          }
          for (final match in selected.reversed) {
            match.replace(replacement);
          }
          if (temporary && source != null) {
            await BookletFile.savePage(source, page);
          }
          count += selected.length;
        } finally {
          if (temporary) page.dispose();
        }
      }
      if (!all && count > 0) break;
    }
    if (count > 0) {
      markDocumentChanged();
      notifyListeners();
    }
    return count;
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

  void addAssetsFolderBelow() {
    final folder = viewModel.addAssetsFolderBelow();
    assetManagerController.selectFolder(folder, _documentPath);
    notifyListeners();
  }

  void addAssetsFolderInside() {
    final folder = viewModel.addAssetsFolderInside();
    assetManagerController.selectFolder(folder, _documentPath);
    notifyListeners();
  }

  Future<void> deleteSelectedNode() => _trashAction(() async {
    final node = viewModel.navigation.selectedNode;
    if (node == null) return;
    // Flush staged pages and preserve the previous day's snapshot first.
    await flushAutoSave();
    if (_autoSaveError != null) {
      throw StateError('Save failed. The item has not been deleted.');
    }
    final extraPages = <PageContent>[];
    late final Map<String, dynamic> bundle;
    try {
      final loadedIds = viewModel.loadedPages.map((page) => page.id).toSet();
      for (final pageNode in _pageNodes(node)) {
        final staged = _navigationPageSources[pageNode.pageId];
        if (staged != null && !loadedIds.contains(pageNode.pageId)) {
          extraPages.add(
            await BookletFile.loadPage(staged, pageNode.pageId!, editorTheme),
          );
        }
      }
      bundle = await BookletFile.exportNavigationSubtree(
        packagePath: _documentPath,
        node: node,
        loadedPages: [...viewModel.loadedPages, ...extraPages],
        theme: editorTheme,
      );
    } finally {
      for (final page in extraPages) {
        page.dispose();
      }
    }
    final package =
        _documentPath ??
        (_unsavedTrashPackage ??= (await Directory.systemTemp.createTemp(
          'booklet_deleted_items',
        )).path);
    await DeletedItems.add(package, bundle);
    // Do not remove any live data until the recoverable copy is durable.
    viewModel.navigation.selectNode(node);
    final removedNode = viewModel.deleteSelectedNode();
    if (removedNode == null) return;
    assetManagerController.selectFolder(
      viewModel.navigation.selectedNode,
      _documentPath,
    );
    await flushAutoSave();
    if (_autoSaveError != null) {
      throw StateError(
        'Deletion could not be saved. A recoverable copy is in Deleted pages and groups.',
      );
    }
    await BookletFile.deleteAssetsForNode(_documentPath, removedNode);
    if (_documentPath != null) {
      for (final page in _pageNodes(removedNode)) {
        final file = File('$_documentPath/pages/${page.pageId}.json');
        if (await file.exists()) await file.delete();
      }
    }
    final selected = viewModel.navigation.selectedNode;
    if (selected != null) await _activateCopiedNode(selected);
  });

  Future<bool> saveBooklet() => _save(saveAs: false);

  Future<bool> saveBookletAs() => _save(saveAs: true);

  Future<bool> _save({required bool saveAs}) async {
    if (examiningSnapshot && saveAs) return false;
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
    await refreshDeletedItems();
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
      if (!examiningSnapshot) await DailySnapshots.rollDay(path);
      for (final entry in _stagedNavigationSubtrees.entries) {
        await BookletFile.copyStagedNavigationPages(
          path,
          entry.key,
          entry.value,
        );
      }
      await _saveLoadedPages();
      final trashSource = sourcePackagePath ?? _unsavedTrashPackage;
      if (trashSource != null) {
        await DeletedItems.copyEntries(trashSource, path);
      }
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
      final temporaryTrash = _unsavedTrashPackage;
      if (temporaryTrash != null && path != temporaryTrash) {
        await Directory(temporaryTrash).delete(recursive: true);
        _unsavedTrashPackage = null;
      }
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
    if (!examiningSnapshot) await DailySnapshots.rollDay(path);
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
    _trashExpiryTimer?.cancel();
    final temporary = _unsavedTrashPackage;
    if (temporary != null) {
      unawaited(Directory(temporary).delete(recursive: true));
    }
    assetManagerController.dispose();
    viewModel.dispose();
    super.dispose();
  }
}

class BookletSearchPage {
  const BookletSearchPage(this.pageId, this.title, this.breadcrumb, this.hits);
  final String pageId;
  final String title;
  final String breadcrumb;
  final List<BookletSearchHit> hits;
}

class BookletSearchHit {
  const BookletSearchHit(this.text, this.start, this.end);
  final String text;
  final int start;
  final int end;
}
