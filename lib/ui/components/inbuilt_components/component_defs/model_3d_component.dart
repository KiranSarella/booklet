import 'dart:async';

import 'package:booklet/ui/components/media/media_caption.dart';
import 'package:booklet/ui/components/model_3d/model_3d_thumbnail_cache.dart';

import 'dart:convert';
import 'dart:io';

import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/business/components_business/component_def.dart';
import 'package:booklet/business/components_business/inbuilt_components/inbuit_components_definations.dart';
import 'package:booklet/ui/components/component.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/components/model_3d/model_3d_importer.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:webview_all/webview_all.dart';

class Model3dComponent implements Component {
  Model3dComponent({required this.id}) : state = Model3dComponentState();
  @override
  final String id;
  @override
  final Model3dComponentState state;
  @override
  ComponentDef get def => Model3dComponentDef();
  @override
  Object? get output => state.output;
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
  }) => Model3dComponentView(
    state: state,
    onSelect: onSelect,
    isSelected: isSelected,
    readOnly: theme.documentSettingsController.isReadOnly,
  );
}

class Model3dComponentView extends StatefulWidget {
  const Model3dComponentView({
    super.key,
    required this.state,
    required this.onSelect,
    this.readOnly = false,
    this.isSelected = false,
  });
  final Model3dComponentState state;
  final VoidCallback onSelect;
  final bool readOnly;
  final bool isSelected;
  @override
  State<Model3dComponentView> createState() => _Model3dComponentViewState();
}

class _Model3dComponentViewState extends State<Model3dComponentView> {
  WebViewController? _controller;
  bool _busy = false;
  String? _error;
  int _generation = 0;
  Uint8List? _thumbnail;
  bool _capturing = false;
  Timer? _captureTimeout;
  String? _loadedPath;

  @override
  void initState() {
    super.initState();
    _loadedPath = widget.state.mediaPath;
    unawaited(_preparePreview(_loadedPath));
  }

  @override
  void didUpdateWidget(covariant Model3dComponentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_loadedPath != widget.state.mediaPath) {
      _loadedPath = widget.state.mediaPath;
      unawaited(_preparePreview(_loadedPath));
    }
  }

  Future<void> _preparePreview(String? path) async {
    final generation = ++_generation;
    _captureTimeout?.cancel();
    _controller = null;
    _thumbnail = null;
    _capturing = false;
    _busy = false;
    _error = null;
    if (path == null) return;
    final thumbnail = await Model3dThumbnailCache.load(path);
    if (!mounted || generation != _generation) return;
    setState(() => _thumbnail = thumbnail);
    if (thumbnail == null) await _view(thumbnail: true);
  }

  Future<void> _import() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: '3D models (glTF 2.0)',
            extensions: ['glb', 'gltf'],
          ),
        ],
      );
      if (file == null || !mounted) return;
      setState(() {
        _busy = true;
        _error = null;
      });
      final bytes = await Model3dImporter.read(File(file.path));
      final directory = await getTemporaryDirectory();
      final extension = file.path.split('.').last.toLowerCase();
      final target = File('${directory.path}/${const Uuid().v4()}.$extension');
      await target.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      _generation++;
      setState(() {
        _controller = null;
        widget.state.mediaPath = target.path;
      });
      _loadedPath = target.path;
      unawaited(_preparePreview(target.path));
      widget.onSelect();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException ? error.message : 'Could not import model. Check that all model files are available.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _view({bool thumbnail = false}) async {
    final path = widget.state.mediaPath;
    if (path == null) return;
    final generation = ++_generation;
    _captureTimeout?.cancel();
    _capturing = thumbnail;
    setState(() {
      _busy = true;
      _error = null;
      _controller = null;
    });
    try {
      final bytes = await File(path).readAsBytes();
      final script = await rootBundle.loadString(
        'assets/3d/model-viewer.min.js',
      );
      final mime = path.toLowerCase().endsWith('.glb')
          ? 'model/gltf-binary'
          : 'model/gltf+json';
      final source = 'data:$mime;base64,${base64Encode(bytes)}';
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      if (!thumbnail) {
        await controller.addJavaScriptChannel(
          'ModelControls',
          onMessageReceived: (message) {
            if (!mounted ||
                generation != _generation ||
                message.message != 'close') {
              return;
            }
            _generation++;
            setState(() {
              _controller = null;
              _busy = false;
            });
          },
        );
      }
      if (thumbnail) {
        await controller.addJavaScriptChannel(
          'ModelPreview',
          onMessageReceived: (message) async {
            if (!mounted || generation != _generation) return;
            _captureTimeout?.cancel();
            Uint8List? image;
            try {
              if (message.message.startsWith('data:image/png;base64,')) {
                image = base64Decode(message.message.split(',').last);
                await Model3dThumbnailCache.save(path, image);
              }
            } catch (_) {
              /* Keep the fallback preview available. */
            }
            if (!mounted || generation != _generation) return;
            setState(() {
              _thumbnail = image;
              _controller = null;
              _capturing = false;
              _busy = false;
            });
          },
        );
      }
      await controller.loadHtmlString('''<!doctype html><html><head>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>html,body{margin:0;height:100%;background:#eeeeee;font:14px system-ui}model-viewer{width:100%;height:${thumbnail ? '100%' : 'calc(100% - 44px)'}}nav{height:44px;display:flex;align-items:center;justify-content:center;gap:8px}button{padding:6px 12px}#status{position:absolute;top:12px;left:12px;right:12px;pointer-events:none}</style>
</head><body><model-viewer id="model" camera-controls touch-action="pan-y" shadow-intensity="1" alt="Interactive 3D model"></model-viewer>
<div id="status" role="status">Loading model…</div>
<nav style="display:${thumbnail ? 'none' : 'flex'}"><button id="reset">Reset view</button><button id="rotate">Auto rotate</button><button id="play">Play / pause</button><button id="close" aria-label="Close viewer">Close</button></nav>
<script type="module">$script</script>
<script>
const model=document.getElementById('model'),status=document.getElementById('status');
model.addEventListener('load',async()=>{status.textContent='';document.getElementById('play').disabled=!model.availableAnimations.length;
if (${thumbnail ? 'true' : 'false'}) {try {await model.updateComplete;await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));ModelPreview.postMessage(model.toDataURL('image/png'));} catch(e) {ModelPreview.postMessage('error');}}
});
model.addEventListener('error',()=>{if (${thumbnail ? 'true' : 'false'}) ModelPreview.postMessage('error');status.textContent='Unable to display this model. It may use unsupported extensions or exceed device limits.';});
customElements.whenDefined('model-viewer').then(()=>{model.src=${jsonEncode(source)};});
document.getElementById('reset').onclick=()=>{model.cameraOrbit='auto auto auto';model.cameraTarget='auto auto auto';model.fieldOfView='auto';model.jumpCameraToGoal();};
document.getElementById('rotate').onclick=()=>{model.autoRotate=!model.autoRotate;};
document.getElementById('play').onclick=()=>{model.paused?model.play():model.pause();};
document.getElementById('close').onclick=()=>{ModelControls.postMessage('close');};
setTimeout(()=>{if(status.textContent==='Loading model…')status.textContent='Still loading. If this persists, check that WebGL is supported and the model uses standard glTF features.';},30000);
</script></body></html>''');
      if (!mounted || generation != _generation || (thumbnail && !_capturing)) {
        return;
      }
      setState(() => _controller = controller);
      if (thumbnail) {
        _captureTimeout = Timer(const Duration(seconds: 30), () {
          if (!mounted || generation != _generation) return;
          _generation++;
          setState(() {
            _controller = null;
            _capturing = false;
            _busy = false;
          });
        });
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _capturing = false;
          _busy = false;
          if (!thumbnail) _error = 'Could not open the 3D viewer. Check the model file and WebView support.';
        });
      }
    } finally {
      if (mounted && generation == _generation && !thumbnail) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    _captureTimeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.state.mediaPath;
    final colors = Theme.of(context).colorScheme;
    final interactive = _controller != null && !_capturing;
    return MediaCaption(
      state: widget.state,
      isSelected: widget.isSelected,
      isReadOnly: widget.readOnly,
      onSelect: widget.onSelect,
      child: GestureDetector(
        onTap: widget.onSelect,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          child: path == null
              ? Container(
                  constraints: const BoxConstraints(minHeight: 180),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(
                      alpha: 0.45,
                    ),
                    border: Border.all(
                      color: colors.outlineVariant,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.view_in_ar_outlined,
                        size: 38,
                        color: colors.primary,
                      ),
                      const SizedBox(height: 8),
                      const Text('3D Model'),
                      const SizedBox(height: 8),
                      if (!widget.readOnly)
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _import,
                          icon: const Icon(Icons.folder_open),
                          label: const Text('Choose model'),
                        ),
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('GLB or glTF 2.0 · Maximum 100 MB'),
                      ),
                      if (_busy)
                        const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(),
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            _error!,
                            style: TextStyle(color: colors.error),
                          ),
                        ),
                    ],
                  ),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xffeeeeee),
                        border: widget.isSelected
                            ? Border.all(color: colors.primary, width: 2)
                            : null,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (_controller != null && _capturing)
                                  IgnorePointer(
                                    child: Opacity(
                                      opacity: 0.01,
                                      child: WebViewWidget(
                                        controller: _controller!,
                                      ),
                                    ),
                                  ),
                                if (interactive)
                                  WebViewWidget(controller: _controller!)
                                else ...[
                                  const ColoredBox(color: Color(0xffeeeeee)),
                                  if (_thumbnail != null)
                                    Image.memory(
                                      _thumbnail!,
                                      fit: BoxFit.contain,
                                    )
                                  else
                                    const Center(
                                      child: Icon(
                                        Icons.view_in_ar_outlined,
                                        size: 64,
                                        color: Colors.black38,
                                      ),
                                    ),
                                  if (_busy)
                                    const Positioned(
                                      top: 12,
                                      right: 12,
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  Center(
                                    child: IconButton.filled(
                                      tooltip: 'Play 3D model',
                                      iconSize: 40,
                                      onPressed: () {
                                        widget.onSelect();
                                        unawaited(_view());
                                      },
                                      icon: const Icon(Icons.play_arrow),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                _error!,
                                style: TextStyle(color: colors.error),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
