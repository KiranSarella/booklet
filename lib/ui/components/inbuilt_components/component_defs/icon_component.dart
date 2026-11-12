import 'dart:convert';
import 'dart:typed_data';

import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/business/components_business/component_def.dart';
import 'package:booklet/business/components_business/inbuilt_components/inbuit_components_definations.dart';
import 'package:booklet/ui/_helpers/color_picker_dialog.dart';
import 'package:booklet/ui/components/component.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image/image.dart' as raster;

enum IconShape { none, corners, circle }

enum IconSize {
  small(32),
  medium(64),
  large(96),
  extraLarge(128);

  const IconSize(this.extent);
  final double extent;
}

enum IconImageFit { fit, fill }

/// Uploaded bytes travel with the component, including clipboard and history.
class IconComponentState extends ComponentState {
  Uint8List? _bytes;
  String? _extension;
  IconShape _shape = IconShape.corners;
  Color? _tint;
  bool _borderEnabled = false;
  IconSize _size = IconSize.medium;
  IconImageFit _imageFit = IconImageFit.fit;

  Uint8List? get bytes => _bytes;
  String? get extension => _extension;
  IconShape get shape => _shape;
  Color? get tint => _tint;
  bool get borderEnabled => _borderEnabled;
  IconSize get size => _size;
  IconImageFit get imageFit => _imageFit;
  BoxFit get boxFit =>
      _imageFit == IconImageFit.fill ? BoxFit.cover : BoxFit.contain;
  Color get borderColor => _tint ?? Colors.grey;

  void setIcon(Uint8List bytes, String extension) {
    _bytes = Uint8List.fromList(bytes);
    _extension = extension;
    notifyListeners();
  }

  void removeIcon() {
    _bytes = null;
    _extension = null;
    notifyListeners();
  }

  void setShape(IconShape value) {
    _shape = value;
    notifyListeners();
  }

  void setTint(Color? value) {
    _tint = value;
    notifyListeners();
  }

  void setBorderEnabled(bool value) {
    _borderEnabled = value;
    notifyListeners();
  }

  void setSize(IconSize value) {
    _size = value;
    notifyListeners();
  }

  void setImageFit(IconImageFit value) {
    _imageFit = value;
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
    if (_bytes != null) 'iconData': base64Encode(_bytes!),
    'iconExtension': _extension,
    'shape': _shape.name,
    'tint': _tint?.toARGB32(),
    'borderEnabled': _borderEnabled,
    'size': _size.name,
    'imageFit': _imageFit.name,
  };

  void restore(Map<String, dynamic> json) {
    final data = json['iconData'];
    _bytes = data is String ? base64Decode(data) : null;
    _extension = json['iconExtension'] as String?;
    _shape = IconShape.values.firstWhere(
      (shape) => shape.name == json['shape'],
      orElse: () => IconShape.corners,
    );
    _tint = json['tint'] is num ? Color((json['tint'] as num).toInt()) : null;
    _borderEnabled =
        json['borderEnabled'] as bool? ??
        ((json['borderWidth'] as num? ?? 0) > 0);
    _size = IconSize.values.firstWhere(
      (size) => size.name == json['size'],
      orElse: () => IconSize.medium,
    );
    _imageFit = json['imageFit'] == 'fill'
        ? IconImageFit.fill
        : IconImageFit.fit;
    notifyListeners();
  }

  @override
  Object get output => toJson();
}

/// Modern ICNS files contain PNG representations at several resolutions.
Uint8List? decodeIcnsPng(Uint8List bytes) {
  if (bytes.length < 8 ||
      ascii.decode(bytes.sublist(0, 4), allowInvalid: true) != 'icns') {
    return null;
  }
  final data = ByteData.sublistView(bytes);
  Uint8List? best;
  const pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];
  for (var offset = 8; offset + 8 <= bytes.length;) {
    final length = data.getUint32(offset + 4);
    if (length < 8 || offset + length > bytes.length) return null;
    final payload = Uint8List.sublistView(bytes, offset + 8, offset + length);
    if (payload.length >= 8 &&
        List.generate(
          8,
          (i) => payload[i] == pngSignature[i],
        ).every((v) => v)) {
      if (best == null || payload.length > best.length) best = payload;
    }
    offset += length;
  }
  return best;
}

class IconComponent implements Component {
  IconComponent({required this.id});

  @override
  final String id;
  @override
  final IconComponentState state = IconComponentState();
  @override
  ComponentDef get def => IconComponentDef();
  @override
  Object get output => state.output;
  @override
  List<dynamic>? get textDelta => null;
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
  }) => IconComponentView(
    state: state,
    theme: theme,
    isSelected: isSelected,
    onSelect: onSelect,
  );
}

class IconComponentView extends StatefulWidget {
  const IconComponentView({
    super.key,
    required this.state,
    required this.theme,
    required this.isSelected,
    required this.onSelect,
  });

  final IconComponentState state;
  final PageSettingsController theme;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  State<IconComponentView> createState() => _IconComponentViewState();
}

class _IconComponentViewState extends State<IconComponentView> {
  static const extensions = [
    'svg',
    'png',
    'webp',
    'jpg',
    'jpeg',
    'gif',
    'bmp',
    'icns',
    'ico',
    'cur',
    'tif',
    'tiff',
    'tga',
    'icb',
    'pbm',
    'pgm',
    'ppm',
    'pnm',
    'psd',
  ];
  bool _dragging = false;
  bool _loading = false;
  bool get _readOnly => widget.theme.documentSettingsController.isReadOnly;

  Future<void> _upload([XFile? dropped]) async {
    if (_readOnly || _loading) return;
    final file =
        dropped ??
        await openFile(
          acceptedTypeGroups: const [
            XTypeGroup(label: 'Icons', extensions: extensions),
          ],
        );
    if (file == null || !mounted || _readOnly) return;
    setState(() => _loading = true);
    try {
      final extension = file.name.split('.').last.toLowerCase();
      if (!extensions.contains(extension)) throw const FormatException();
      var bytes = await file.readAsBytes();
      var storedExtension = extension;
      if (extension == 'icns') {
        bytes = decodeIcnsPng(bytes) ?? (throw const FormatException());
        storedExtension = 'png';
      } else if (extension != 'svg') {
        // Normalize formats such as ICO, CUR, TIFF and PSD for Flutter rendering.
        final decoded = raster.decodeImage(bytes);
        if (decoded == null) throw const FormatException();
        bytes = raster.encodePng(decoded);
        storedExtension = 'png';
      } else {
        final text = utf8.decode(bytes);
        if (!text.contains('<svg')) throw const FormatException();
      }
      if (!mounted || _readOnly) return;
      widget.state.setIcon(bytes, storedExtension);
      widget.onSelect();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load this icon file.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickTint() async {
    final color = await showDialog<Color>(
      context: context,
      builder: (_) => ColorPickerDialog(
        initialColor: widget.state.tint ?? widget.theme.styleColor,
      ),
    );
    if (color != null && mounted && !_readOnly) widget.state.setTint(color);
  }

  Widget _icon() {
    final state = widget.state;
    final zoom = widget.theme.baseFontSize / widget.theme.originalBaseFontSize;
    final extent = state.size.extent * zoom;
    final radius = BorderRadius.circular(switch (state.shape) {
      IconShape.none => 0,
      IconShape.corners => extent * 0.1875,
      IconShape.circle => extent / 2,
    });
    final filter = state.tint == null
        ? null
        : ColorFilter.mode(state.tint!, BlendMode.srcIn);
    const unavailable = Center(child: Icon(Icons.broken_image_outlined));
    Widget content;
    if (_loading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (state.bytes == null) {
      content = Icon(Icons.image_outlined, color: widget.theme.styleColor);
    } else if (state.extension == 'svg') {
      content = SvgPicture.memory(
        state.bytes!,
        fit: state.boxFit,
        colorFilter: filter,
        errorBuilder: (_, _, _) => unavailable,
      );
    } else {
      content = Image.memory(
        state.bytes!,
        fit: state.boxFit,
        color: state.tint,
        colorBlendMode: state.tint == null ? null : BlendMode.srcIn,
        errorBuilder: (_, _, _) => unavailable,
      );
    }
    return Tooltip(
      message: 'Icon',
      child: GestureDetector(
        onTap: widget.onSelect,
        child: SizedBox.square(
          dimension: extent,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: state.borderColor,
                width: 1,
                style: state.borderEnabled
                    ? BorderStyle.solid
                    : BorderStyle.none,
              ),
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: ColoredBox(
                color: _dragging
                    ? widget.theme.styleColor.withValues(alpha: 0.15)
                    : Colors.transparent,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _editControls() => Wrap(
    spacing: 12,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      TextButton.icon(
        onPressed: _loading ? null : () => _upload(),
        icon: const Icon(Icons.upload_outlined),
        label: const Text('Upload'),
      ),
      DropdownButton<IconShape>(
        value: widget.state.shape,
        items: [
          for (final shape in IconShape.values)
            DropdownMenuItem(
              value: shape,
              child: Text(switch (shape) {
                IconShape.none => 'None',
                IconShape.corners => 'Corners',
                IconShape.circle => 'Circle',
              }),
            ),
        ],
        onChanged: (shape) {
          if (shape != null) widget.state.setShape(shape);
        },
      ),
      DropdownButton<IconSize>(
        value: widget.state.size,
        items: [
          for (final size in IconSize.values)
            DropdownMenuItem(
              value: size,
              child: Text('${size.extent.toInt()}×${size.extent.toInt()}'),
            ),
        ],
        onChanged: (size) {
          if (size != null) widget.state.setSize(size);
        },
      ),
      DropdownButton<IconImageFit>(
        value: widget.state.imageFit,
        items: const [
          DropdownMenuItem(value: IconImageFit.fit, child: Text('Fit')),
          DropdownMenuItem(value: IconImageFit.fill, child: Text('Fill')),
        ],
        onChanged: (fit) {
          if (fit != null) widget.state.setImageFit(fit);
        },
      ),
      TextButton.icon(
        onPressed: _pickTint,
        icon: Icon(Icons.palette_outlined, color: widget.state.tint),
        label: const Text('Tint color'),
      ),
      if (widget.state.tint != null)
        IconButton(
          tooltip: 'Clear tint',
          onPressed: () => widget.state.setTint(null),
          icon: const Icon(Icons.format_color_reset),
        ),
      IconButton(
        tooltip: widget.state.borderEnabled
            ? 'Disable border'
            : 'Enable border',
        isSelected: widget.state.borderEnabled,
        onPressed: () =>
            widget.state.setBorderEnabled(!widget.state.borderEnabled),
        icon: const Icon(Icons.border_clear),
        selectedIcon: Icon(Icons.border_outer, color: widget.state.borderColor),
      ),
    ],
  );

  Future<void> _showOptions() async {
    widget.onSelect();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Icon options'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: ListenableBuilder(
              listenable: widget.state,
              builder: (context, _) => _editControls(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.state, widget.theme]),
    builder: (context, _) => DropTarget(
      enable: !_readOnly,
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) {
        setState(() => _dragging = false);
        if (details.files.isNotEmpty) _upload(details.files.first);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final extent =
                widget.state.size.extent *
                widget.theme.baseFontSize /
                widget.theme.originalBaseFontSize;
            if (constraints.maxWidth < extent + 300) {
              return Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: extent.clamp(0, constraints.maxWidth),
                  child: Stack(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: _icon(),
                      ),
                      if (!_readOnly &&
                          (ComposedSelectionScope.selectionOf(context) ?? widget.isSelected))
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: IconButton.filledTonal(
                            tooltip: 'Icon options',
                            constraints: const BoxConstraints.tightFor(
                              width: 28,
                              height: 28,
                            ),
                            padding: EdgeInsets.zero,
                            iconSize: 16,
                            onPressed: _showOptions,
                            icon: const Icon(Icons.tune),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _icon(),
                if (widget.isSelected && !_readOnly) ...[
                  const SizedBox(width: 16),
                  Expanded(child: _editControls()),
                ],
              ],
            );
          },
        ),
      ),
    ),
  );
}
