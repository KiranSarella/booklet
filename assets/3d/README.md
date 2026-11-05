# Bundled 3D viewer

`model-viewer.min.js` is the unmodified @google/model-viewer 4.0.0 distribution:
https://unpkg.com/@google/model-viewer@4.0.0/dist/model-viewer.min.js

Apache-2.0 license: LICENSE. The distribution retains dependency license notices.
Runtime size is approximately 934 KiB before application compression. No new
Flutter package or native rendering engine is required; rendering uses the
existing webview_all integration and WebGL.

The 3D Model component imports local glTF 2.0 (.gltf) and self-contained binary glTF
(.glb). glTF buffers and images inside the selected model folder are embedded
as data URIs before saving. Remote dependencies and references outside that
folder are rejected. Imports are limited to 100 MiB including dependencies.

Standard models work offline. Some compressed models or glTF extensions may
require decoder downloads by model-viewer or may be unsupported. WebGL support
and available GPU memory depend on the platform's WebView. The viewer opens
on demand and offers orbit, pan, zoom, reset, auto-rotation and animation
play/pause. Camera position is session-only. A rendered PNG thumbnail is generated on import
and cached by model content in the application cache directory. The component
displays that thumbnail with a Play button until the interactive viewer opens.
The caption uses the same selection and editing behavior as the video component.

Model files and captions use the normal document media persistence and
component clipboard paths. OBJ, STL, PLY, FBX, USDZ and authoring/CAD formats
are not supported by this first version.
