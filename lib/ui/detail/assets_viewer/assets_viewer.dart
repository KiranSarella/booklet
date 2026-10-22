import 'dart:io';

import 'package:booklet/application/asset_manager_controller.dart';
import 'package:booklet/business/booklet_asset.dart';
import 'package:booklet/ui/detail/assets_viewer/media_slideshow_dialog.dart';
import 'package:flutter/material.dart';

enum _AssetLayout { list, icons }

enum _AssetAction { rename, delete, preview }

class AssetsViewer extends StatefulWidget {
  const AssetsViewer({
    super.key,
    required this.controller,
    required this.isReadOnly,
  });

  final AssetManagerController controller;
  final bool isReadOnly;

  @override
  State<AssetsViewer> createState() => _AssetsViewerState();
}

class _AssetsViewerState extends State<AssetsViewer> {
  _AssetLayout _layout = _AssetLayout.list;

  Future<void> _addAssets() async {
    try {
      await widget.controller.addAssets();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not add assets: $error')));
    }
  }

  Future<void> _openAsset(BookletAsset asset) async {
    if (asset.kind == BookletAssetKind.image ||
        asset.kind == BookletAssetKind.video) {
      final media =
          widget.controller.assets
              .where(
                (item) =>
                    item.kind == BookletAssetKind.image ||
                    item.kind == BookletAssetKind.video,
              )
              .toList()
            ..sort((left, right) {
              final byLowercaseName = left.name.toLowerCase().compareTo(
                right.name.toLowerCase(),
              );
              return byLowercaseName != 0
                  ? byLowercaseName
                  : left.name.compareTo(right.name);
            });
      await showDialog<void>(
        context: context,
        builder: (_) => MediaSlideshowDialog(
          assets: media,
          initialIndex: media.indexWhere((item) => item.id == asset.id),
          resolvePath: widget.controller.resolvePath,
          resolveThumbnailPath: widget.controller.resolveThumbnailPath,
        ),
      );
      return;
    }
    switch (asset.kind) {
      case BookletAssetKind.image:
      case BookletAssetKind.video:
        return;
      case BookletAssetKind.pdf:
      case BookletAssetKind.document:
      case BookletAssetKind.file:
        final opened = await widget.controller.openWithSystemApp(asset);
        if (!opened && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No app could open ${asset.name}.')),
          );
        }
    }
  }

  Future<void> _renameSelectedAsset() async {
    final asset = widget.controller.selectedAsset;
    if (asset == null) return;
    final extension = asset.extension;
    final baseName = extension.isEmpty
        ? asset.name
        : asset.name.substring(0, asset.name.length - extension.length - 1);
    final newBaseName = await showDialog<String>(
      context: context,
      builder: (context) =>
          _RenameAssetDialog(baseName: baseName, extension: extension),
    );
    if (newBaseName == null || newBaseName.trim().isEmpty) return;
    try {
      widget.controller.renameSelectedAsset(newBaseName);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not rename asset: $error')));
    }
  }

  Future<void> _deleteSelectedAsset() async {
    try {
      await widget.controller.deleteSelectedAsset();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete asset: $error')));
    }
  }

  void _runAssetAction(_AssetAction action) {
    final asset = widget.controller.selectedAsset;
    if (asset == null) return;
    switch (action) {
      case _AssetAction.rename:
        _renameSelectedAsset();
      case _AssetAction.delete:
        _deleteSelectedAsset();
      case _AssetAction.preview:
        _openAsset(asset);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final folder = widget.controller.folder;
        final selectedAsset = widget.controller.selectedAsset;
        final assets = widget.controller.assets.toList()
          ..sort((left, right) {
            final byLowercaseName = left.name.toLowerCase().compareTo(
              right.name.toLowerCase(),
            );
            return byLowercaseName != 0
                ? byLowercaseName
                : left.name.compareTo(right.name);
          });
        final colors = Theme.of(context).colorScheme;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 20, 12),
              child: Row(
                children: [
                  Icon(Icons.folder_open_outlined, color: colors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      folder?.title ?? 'Assets',
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  SegmentedButton<_AssetLayout>(
                    segments: const [
                      ButtonSegment(
                        value: _AssetLayout.list,
                        icon: Icon(Icons.view_list_outlined),
                        label: Text('List'),
                      ),
                      ButtonSegment(
                        value: _AssetLayout.icons,
                        icon: Icon(Icons.grid_view_outlined),
                        label: Text('Icons'),
                      ),
                    ],
                    selected: {_layout},
                    onSelectionChanged: (selection) =>
                        setState(() => _layout = selection.first),
                  ),
                  const SizedBox(width: 12),
                  if (!widget.isReadOnly) ...[
                    FilledButton.icon(
                      onPressed: widget.controller.isAddingAssets
                          ? null
                          : _addAssets,
                      icon: widget.controller.isAddingAssets
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add),
                      label: const Text('Add asset'),
                    ),
                    PopupMenuButton<_AssetAction>(
                      enabled: selectedAsset != null,
                      tooltip: 'More asset options',
                      onSelected: _runAssetAction,
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: _AssetAction.rename,
                          child: ListTile(
                            leading: Icon(Icons.edit_outlined),
                            title: Text('Rename'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: _AssetAction.delete,
                          child: ListTile(
                            leading: Icon(Icons.delete_outline),
                            title: Text('Delete'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: _AssetAction.preview,
                          child: ListTile(
                            leading: Icon(Icons.open_in_full),
                            title: Text('Preview'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: assets.isEmpty
                  ? Center(
                      child: Text(
                        'No assets in this folder',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    )
                  : _layout == _AssetLayout.list
                  ? ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: assets.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) => _AssetListTile(
                        asset: assets[index],
                        thumbnailPath: widget.controller.resolveThumbnailPath(
                          assets[index],
                        ),
                        isSelected: selectedAsset?.id == assets[index].id,
                        onTap: () =>
                            widget.controller.selectAsset(assets[index]),
                        onDoubleTap: () => _openAsset(assets[index]),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(20),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 156,
                            mainAxisExtent: 132,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                      itemCount: assets.length,
                      itemBuilder: (context, index) => _AssetIconTile(
                        asset: assets[index],
                        thumbnailPath: widget.controller.resolveThumbnailPath(
                          assets[index],
                        ),
                        isSelected: selectedAsset?.id == assets[index].id,
                        onTap: () =>
                            widget.controller.selectAsset(assets[index]),
                        onDoubleTap: () => _openAsset(assets[index]),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _RenameAssetDialog extends StatefulWidget {
  const _RenameAssetDialog({required this.baseName, required this.extension});

  final String baseName;
  final String extension;

  @override
  State<_RenameAssetDialog> createState() => _RenameAssetDialogState();
}

class _RenameAssetDialogState extends State<_RenameAssetDialog> {
  late final TextEditingController _textController = TextEditingController(
    text: widget.baseName,
  );

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename asset'),
      content: TextField(
        autofocus: true,
        controller: _textController,
        decoration: InputDecoration(
          labelText: 'File name',
          suffixText: widget.extension.isEmpty ? null : '.${widget.extension}',
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_textController.text),
          child: const Text('Rename'),
        ),
      ],
    );
  }
}

class _AssetListTile extends StatelessWidget {
  const _AssetListTile({
    required this.asset,
    required this.thumbnailPath,
    required this.isSelected,
    required this.onTap,
    required this.onDoubleTap,
  });

  final BookletAsset asset;
  final String? thumbnailPath;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: isSelected ? colors.secondaryContainer : null,
      child: InkWell(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _AssetIcon(
                  asset: asset,
                  size: 40,
                  thumbnailPath: thumbnailPath,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        asset.extension.isEmpty ? 'File' : asset.extension,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AssetIconTile extends StatelessWidget {
  const _AssetIconTile({
    required this.asset,
    required this.thumbnailPath,
    required this.isSelected,
    required this.onTap,
    required this.onDoubleTap,
  });

  final BookletAsset asset;
  final String? thumbnailPath;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? colors.secondaryContainer : null,
          border: Border.all(
            color: isSelected ? colors.primary : Colors.transparent,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _AssetIcon(asset: asset, size: 64, thumbnailPath: thumbnailPath),
            const SizedBox(height: 10),
            Text(
              asset.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurface, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssetIcon extends StatelessWidget {
  const _AssetIcon({
    required this.asset,
    required this.size,
    this.thumbnailPath,
  });

  final BookletAsset asset;
  final double size;
  final String? thumbnailPath;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (asset.kind) {
      BookletAssetKind.image => (Icons.image_outlined, Colors.teal),
      BookletAssetKind.video => (Icons.movie_outlined, Colors.deepOrange),
      BookletAssetKind.pdf => (Icons.picture_as_pdf_outlined, Colors.red),
      BookletAssetKind.document => (Icons.description_outlined, Colors.blue),
      BookletAssetKind.file => (Icons.insert_drive_file_outlined, Colors.grey),
    };
    if ((asset.kind == BookletAssetKind.image ||
            asset.kind == BookletAssetKind.video) &&
        thumbnailPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Image.file(
          File(thumbnailPath!),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Icon(icon, size: size, color: color),
        ),
      );
    }
    return Icon(icon, size: size, color: color);
  }
}
