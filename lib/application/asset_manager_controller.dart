import 'dart:io';

import 'package:booklet/business/booklet_asset.dart';
import 'package:booklet/storage/booklet_file.dart';
import 'package:booklet/ui/sidebar/pages_navigation/navigation_node.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class AssetManagerController extends ChangeNotifier {
  VoidCallback? onDocumentChanged;
  NavigationNode? _folder;
  String? _packagePath;
  String? _selectedAssetId;
  bool _isAddingAssets = false;

  NavigationNode? get folder => _folder;
  bool get isAddingAssets => _isAddingAssets;
  List<BookletAsset> get assets => _folder?.assets ?? const [];
  BookletAsset? get selectedAsset {
    final selectedId = _selectedAssetId;
    if (selectedId == null) return null;
    for (final asset in assets) {
      if (asset.id == selectedId) return asset;
    }
    return null;
  }

  void selectFolder(NavigationNode? folder, String? packagePath) {
    if (_folder != folder) {
      _selectedAssetId = null;
    }
    _folder = folder?.isAssetsFolder == true ? folder : null;
    _packagePath = packagePath;
    notifyListeners();
  }

  void selectAsset(BookletAsset asset) {
    if (!assets.any((candidate) => candidate.id == asset.id)) return;
    _selectedAssetId = asset.id;
    notifyListeners();
  }

  void renameSelectedAsset(String baseName) {
    final asset = selectedAsset;
    final folder = _folder;
    final name = baseName.trim();
    if (asset == null || folder == null || name.isEmpty) return;
    if (name.contains('/') || name.contains('\\')) {
      throw ArgumentError('File names cannot contain path separators.');
    }
    final extension = asset.extension;
    final newName = extension.isEmpty ? name : '$name.$extension';
    final assetIndex = folder.assets.indexWhere(
      (candidate) => candidate.id == asset.id,
    );
    folder.assets[assetIndex] = BookletAsset(
      id: asset.id,
      name: newName,
      path: asset.path,
    );
    notifyListeners();
    onDocumentChanged?.call();
  }

  Future<void> deleteSelectedAsset() async {
    final asset = selectedAsset;
    final folder = _folder;
    if (asset == null || folder == null) return;
    final path = resolvePath(asset);
    folder.assets.removeWhere((candidate) => candidate.id == asset.id);
    _selectedAssetId = null;
    notifyListeners();
    onDocumentChanged?.call();
    final managedAssetPrefix = 'assets/${folder.folderId}/';
    if (_packagePath != null && asset.path.startsWith(managedAssetPrefix)) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> addAssets() async {
    final folder = _folder;
    final packagePath = _packagePath;
    if (folder == null || _isAddingAssets) {
      return;
    }

    _isAddingAssets = true;
    notifyListeners();
    try {
      final files = await BookletFile.chooseAssets();
      if (files.isNotEmpty) {
        final imported = await BookletFile.importAssets(
          packagePath: packagePath,
          folderId: folder.folderId!,
          files: files,
        );
        folder.assets.addAll(imported);
        onDocumentChanged?.call();
      }
    } finally {
      _isAddingAssets = false;
      notifyListeners();
    }
  }

  String resolvePath(BookletAsset asset) {
    if (File(asset.path).isAbsolute || _packagePath == null) {
      return asset.path;
    }
    return '$_packagePath/${asset.path}';
  }

  Future<bool> openWithSystemApp(BookletAsset asset) => launchUrl(
    Uri.file(resolvePath(asset)),
    mode: LaunchMode.externalApplication,
  );
}
