import 'dart:io';

import 'package:booklet/business/booklet_asset.dart';
import 'package:booklet/storage/booklet_file.dart';
import 'package:booklet/ui/navigation/navigation_node.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class AssetManagerController extends ChangeNotifier {
  NavigationNode? _folder;
  String? _packagePath;
  bool _isAddingAssets = false;

  NavigationNode? get folder => _folder;
  bool get isAddingAssets => _isAddingAssets;
  List<BookletAsset> get assets => _folder?.assets ?? const [];

  void selectFolder(NavigationNode? folder, String? packagePath) {
    _folder = folder?.isAssetsFolder == true ? folder : null;
    _packagePath = packagePath;
    notifyListeners();
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
