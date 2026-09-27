import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/components/component.dart';
import 'package:booklet/business/components_business/component_def.dart';
import 'package:booklet/business/components_business/inbuilt_components/inbuit_components_definations.dart';
import 'package:booklet/application/page_settings_controller.dart';

class ImageComponent implements Component {
  ImageComponent({required this.id, String? mediaPath})
    : state = ImageComponentState(mediaPath: mediaPath);

  @override
  final String id;

  @override
  final ImageComponentState state;

  @override
  ComponentDef get def => ImageComponentDef();

  @override
  Object? get output => state.output;

  @override
  List<dynamic>? get textDelta => state.textDelta;

  @override
  void initialize({List<dynamic>? delta}) {}

  @override
  void dispose() => state.dispose();

  @override
  Widget buildUI({
    required PageSettingsController theme,
    required ComponentState componentState,
    required bool isSelected,
    required VoidCallback onSelect,
    required VoidCallback onCreateBelow,
  }) {
    return ImageComponentView(
      state: state,
      theme: theme,
      isSelected: isSelected,
      onSelect: onSelect,
    );
  }
}

class ImageComponentView extends StatefulWidget {
  const ImageComponentView({
    super.key,
    required this.state,
    required this.theme,
    required this.isSelected,
    required this.onSelect,
  });

  final ImageComponentState state;
  final PageSettingsController theme;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  State<ImageComponentView> createState() => _ImageComponentViewState();
}

enum _ImageSize {
  small('Small', 280),
  medium('Medium', 480),
  large('Large', 720);

  const _ImageSize(this.label, this.maxExtent);

  final String label;
  final double maxExtent;
}

class _ImageComponentViewState extends State<ImageComponentView> {
  static const _imageExtensions = <String>[
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'heic',
    'heif',
  ];

  _ImageSize _size = _ImageSize.medium;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _size = _parseSize(widget.state.imageSize);
  }

  static _ImageSize _parseSize(String? value) {
    switch (value) {
      case 'small':
        return _ImageSize.small;
      case 'large':
        return _ImageSize.large;
      case 'medium':
      default:
        return _ImageSize.medium;
    }
  }

  Future<void> _chooseImage() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Images',
          extensions: _imageExtensions,
          mimeTypes: ['image/*'],
        ),
      ],
    );
    if (file != null) {
      _setImage(file.path);
    }
  }

  Future<void> _setImage(String path) async {
    if (path.isEmpty || !_isImagePath(path)) {
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      widget.state.mediaPath = path;
      widget.state.imageSize ??= _ImageSize.medium.name;
      _size = _parseSize(widget.state.imageSize);
    });
    widget.onSelect();
  }

  bool _isImagePath(String path) {
    final extension = path.split('.').last.toLowerCase();
    return _imageExtensions.contains(extension);
  }

  void _showPreview() {
    final path = widget.state.mediaPath;
    if (path == null || path.isEmpty) {
      return;
    }
    showDialog<void>(
      context: context,
      barrierColor: const Color.fromARGB(123, 0, 0, 0),
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: _buildImage(path, fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Close preview',
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String path, {BoxFit fit = BoxFit.contain}) {
    final uri = Uri.tryParse(path);
    final isRemote = uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https');
    if (isRemote) {
      return Image.network(
        path,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            const _ImageUnavailable(),
      );
    }
    return Image.file(
      File(path),
      fit: fit,
      errorBuilder: (context, error, stackTrace) =>
          const _ImageUnavailable(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.state.mediaPath;
    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (detail) async {
        setState(() => _isDragging = false);
        for (final file in detail.files) {
          if (_isImagePath(file.path)) {
            await _setImage(file.path);
            break;
          }
        }
      },
      child: GestureDetector(
        onTap: widget.onSelect,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: path == null || path.isEmpty
                  ? _EmptyImageState(
                      isDragging: _isDragging,
                      onChooseImage: _chooseImage,
                    )
                  : Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: _size.maxExtent,
                          maxHeight: _size.maxExtent,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: _buildImage(path),
                        ),
                      ),
                    ),
            ),
            if (widget.isSelected && path != null && path.isNotEmpty)
              _ImageToolbar(
                selectedSize: _size,
                onSizeChanged: (size) {
                  setState(() {
                    _size = size;
                    widget.state.imageSize = size.name;
                  });
                },
                onExpand: _showPreview,
              ),
          ],
        ),
      ),
    );
  }
}

class _ImageToolbar extends StatelessWidget {
  const _ImageToolbar({
    required this.selectedSize,
    required this.onSizeChanged,
    required this.onExpand,
  });

  final _ImageSize selectedSize;
  final ValueChanged<_ImageSize> onSizeChanged;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.78),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final size in _ImageSize.values)
              _SizeButton(
                label: size.label,
                selected: selectedSize == size,
                onPressed: () => onSizeChanged(size),
              ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: onExpand,
              tooltip: 'Expand image',
              icon: const Icon(Icons.open_in_full, size: 18),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _SizeButton extends StatelessWidget {
  const _SizeButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: selected
            ? Theme.of(context).colorScheme.primaryContainer
            : Colors.transparent,
      ),
      child: Text(label),
    );
  }
}

class _EmptyImageState extends StatelessWidget {
  const _EmptyImageState({required this.isDragging, required this.onChooseImage});

  final bool isDragging;
  final VoidCallback onChooseImage;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 180),
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDragging
            ? colorScheme.primaryContainer.withValues(alpha: 0.55)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        border: Border.all(
          color: isDragging ? colorScheme.primary : colorScheme.outlineVariant,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, size: 38, color: colorScheme.primary),
          const SizedBox(height: 8),
          Text(isDragging ? 'Drop image here' : 'Drag an image here'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onChooseImage,
            icon: const Icon(Icons.folder_open),
            label: const Text('Choose image'),
          ),
        ],
      ),
    );
  }
}

class _ImageUnavailable extends StatelessWidget {
  const _ImageUnavailable();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 180,
      width: 260,
      child: Center(child: Text('Image unavailable')),
    );
  }
}
