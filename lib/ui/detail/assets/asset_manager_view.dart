import 'dart:async';
import 'dart:io';

import 'package:booklet/application/asset_manager_controller.dart';
import 'package:booklet/business/booklet_asset.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

enum _AssetLayout { list, icons }

enum _AssetAction { rename, delete, preview }

class AssetManagerView extends StatefulWidget {
  const AssetManagerView({super.key, required this.controller});

  final AssetManagerController controller;

  @override
  State<AssetManagerView> createState() => _AssetManagerViewState();
}

class _AssetManagerViewState extends State<AssetManagerView> {
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
    final path = widget.controller.resolvePath(asset);
    switch (asset.kind) {
      case BookletAssetKind.image:
        await showDialog<void>(
          context: context,
          builder: (_) => _ImagePreviewDialog(name: asset.name, path: path),
        );
      case BookletAssetKind.video:
        await showDialog<void>(
          context: context,
          builder: (_) => _VideoPreviewDialog(name: asset.name, path: path),
        );
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
    required this.isSelected,
    required this.onTap,
    required this.onDoubleTap,
  });

  final BookletAsset asset;
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
                _AssetIcon(asset: asset, size: 24),
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
    required this.isSelected,
    required this.onTap,
    required this.onDoubleTap,
  });

  final BookletAsset asset;
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
            _AssetIcon(asset: asset, size: 42),
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
  const _AssetIcon({required this.asset, required this.size});

  final BookletAsset asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (asset.kind) {
      BookletAssetKind.image => (Icons.image_outlined, Colors.teal),
      BookletAssetKind.video => (Icons.movie_outlined, Colors.deepOrange),
      BookletAssetKind.pdf => (Icons.picture_as_pdf_outlined, Colors.red),
      BookletAssetKind.document => (Icons.description_outlined, Colors.blue),
      BookletAssetKind.file => (Icons.insert_drive_file_outlined, Colors.grey),
    };
    return Icon(icon, size: size, color: color);
  }
}

class _ImagePreviewDialog extends StatelessWidget {
  const _ImagePreviewDialog({required this.name, required this.path});

  final String name;
  final String path;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: ColoredBox(
        color: Colors.black,
        child: SafeArea(
          child: Column(
            children: [
              _PreviewToolbar(name: name),
              Expanded(
                child: InteractiveViewer(
                  child: Center(
                    child: Image.file(
                      File(path),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white70,
                        size: 72,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoPreviewDialog extends StatefulWidget {
  const _VideoPreviewDialog({required this.name, required this.path});

  final String name;
  final String path;

  @override
  State<_VideoPreviewDialog> createState() => _VideoPreviewDialogState();
}

class _VideoPreviewDialogState extends State<_VideoPreviewDialog> {
  late final VideoPlayerController _player = VideoPlayerController.file(
    File(widget.path),
  );
  bool _initialized = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      await _player.initialize();
      if (mounted) setState(() => _initialized = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: ColoredBox(
        color: Colors.black,
        child: SafeArea(
          child: Column(
            children: [
              _PreviewToolbar(name: widget.name),
              Expanded(
                child: Center(
                  child: _initialized
                      ? AspectRatio(
                          aspectRatio: _player.value.aspectRatio,
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              VideoPlayer(_player),
                              VideoProgressIndicator(
                                _player,
                                allowScrubbing: true,
                                padding: const EdgeInsets.all(12),
                              ),
                              Align(
                                alignment: Alignment.center,
                                child: IconButton.filledTonal(
                                  tooltip: _player.value.isPlaying
                                      ? 'Pause'
                                      : 'Play',
                                  onPressed: () => setState(() {
                                    _player.value.isPlaying
                                        ? _player.pause()
                                        : _player.play();
                                  }),
                                  icon: Icon(
                                    _player.value.isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : _failed
                      ? const Text(
                          'Could not preview this video',
                          style: TextStyle(color: Colors.white),
                        )
                      : const CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewToolbar extends StatelessWidget {
  const _PreviewToolbar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Spacer(),
        Expanded(
          flex: 8,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Close preview',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
