import 'dart:io';
import 'dart:ui' as ui;

import 'package:booklet/business/booklet_asset.dart';
import 'package:booklet/storage/booklet_file.dart';
import 'package:booklet/ui/sidebar/pages_navigation/navigation_node.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

enum AssetLayout { list, icons }

class AssetManagerController extends ChangeNotifier {
  static const _macOsThumbnailChannel = MethodChannel(
    'booklet/video_thumbnail',
  );
  VoidCallback? onDocumentChanged;
  NavigationNode? _folder;
  String? _packagePath;
  String? _selectedAssetId;
  bool _isAddingAssets = false;
  bool _isGeneratingThumbnails = false;
  bool _isDisposed = false;

  AssetLayout _layout = AssetLayout.list;
  AssetLayout get layout => _layout;

  void setLayout(AssetLayout value) {
    if (_layout == value) return;
    _layout = value;
    notifyListeners();
  }

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
      thumbnailPath: asset.thumbnailPath,
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
      final thumbnailPath = resolveThumbnailPath(asset);
      if (thumbnailPath != null) {
        final thumbnail = File(thumbnailPath);
        if (await thumbnail.exists()) await thumbnail.delete();
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
        await _createThumbnails(imported);
        onDocumentChanged?.call();
      }
    } finally {
      _isAddingAssets = false;
      notifyListeners();
    }
  }

  Future<void> generateMissingThumbnails() async {
    if (_isGeneratingThumbnails || _isDisposed) return;
    _isGeneratingThumbnails = true;
    final folder = _folder;
    try {
      final missing = <BookletAsset>[];
      for (final asset in assets.toList()) {
        if (asset.kind != BookletAssetKind.image &&
            asset.kind != BookletAssetKind.video) {
          continue;
        }
        final thumbnail = resolveThumbnailPath(asset);
        if (thumbnail == null || !await File(thumbnail).exists()) {
          missing.add(asset);
        }
      }
      if (missing.isEmpty || _isDisposed || folder != _folder) return;
      await _createThumbnails(missing);
      if (!_isDisposed) {
        notifyListeners();
        onDocumentChanged?.call();
      }
    } on FileSystemException {
      // A missing source or unavailable cache must not prevent viewing assets.
    } finally {
      _isGeneratingThumbnails = false;
    }
  }

  Future<void> _createThumbnails(List<BookletAsset> imported) async {
    final packagePath = _packagePath;
    final folder = _folder;
    if (folder?.folderId == null || imported.isEmpty) return;
    // Inline components and unsaved folders have no package path yet. Keep
    // their previews available until saving copies them into the package.
    final directory = packagePath == null
        ? await Directory.systemTemp.createTemp('booklet_thumbnails_')
        : Directory('$packagePath/assets/${folder!.folderId}/thumbnails');
    await directory.create(recursive: true);
    for (var index = 0; index < imported.length; index++) {
      final asset = imported[index];
      final source = File(resolvePath(asset));
      if (!await source.exists() ||
          (asset.kind != BookletAssetKind.image &&
              asset.kind != BookletAssetKind.video)) {
        continue;
      }
      final thumbnailExtension =
          asset.kind == BookletAssetKind.image ||
              (asset.kind == BookletAssetKind.video && Platform.isMacOS)
          ? 'png'
          : 'jpg';
      final thumbnail = File(
        '${directory.path}/${asset.id}.$thumbnailExtension',
      );
      try {
        if (asset.kind == BookletAssetKind.image) {
          final codec = await ui.instantiateImageCodec(
            await source.readAsBytes(),
            targetWidth: 320,
          );
          final frame = await codec.getNextFrame();
          final bytes = await frame.image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (bytes != null) {
            await thumbnail.writeAsBytes(bytes.buffer.asUint8List());
          }
          frame.image.dispose();
          codec.dispose();
        } else {
          if (Platform.isMacOS) {
            await _macOsThumbnailChannel.invokeMethod<bool>(
              'createVideoThumbnail',
              {'videoPath': source.path, 'thumbnailPath': thumbnail.path},
            );
          } else {
            final bytes = await VideoThumbnail.thumbnailData(
              video: source.path,
              imageFormat: ImageFormat.JPEG,
              maxWidth: 320,
              quality: 75,
            );
            if (bytes != null) await thumbnail.writeAsBytes(bytes);
          }
        }
        if (await thumbnail.exists() && await thumbnail.length() > 0) {
          final assetIndex = folder!.assets.indexWhere(
            (item) => item.id == asset.id,
          );
          if (assetIndex < 0 || _isDisposed) continue;
          final current = folder.assets[assetIndex];
          final updated = BookletAsset(
            id: current.id,
            name: current.name,
            path: current.path,
            thumbnailPath: packagePath == null
                ? thumbnail.path
                : 'assets/${folder.folderId}/thumbnails/${asset.id}.$thumbnailExtension',
          );
          imported[index] = updated;
          folder.assets[assetIndex] = updated;
        }
      } catch (_) {
        // Keep the asset usable when the platform cannot extract a preview.
      }
    }
  }

  String? resolveThumbnailPath(BookletAsset asset) {
    final path = asset.thumbnailPath;
    if (path == null) return null;
    if (File(path).isAbsolute || _packagePath == null) return path;
    return '$_packagePath/$path';
  }

  String resolvePath(BookletAsset asset) {
    if (File(asset.path).isAbsolute || _packagePath == null) {
      return asset.path;
    }
    return '$_packagePath/${asset.path}';
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<bool> openWithSystemApp(BookletAsset asset) => launchUrl(
    Uri.file(resolvePath(asset)),
    mode: LaunchMode.externalApplication,
  );
}
