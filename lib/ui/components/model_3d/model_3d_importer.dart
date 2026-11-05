import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Imports glTF 2.0 as a self-contained file, preserving relative dependencies.
class Model3dImporter {
  static const maxBytes = 100 * 1024 * 1024;

  static Future<Uint8List> read(File file) async {
    if (await file.length() > maxBytes) {
      throw const FormatException('Models must be smaller than 100 MB.');
    }
    final bytes = await file.readAsBytes();
    final extension = file.path.split('.').last.toLowerCase();
    if (extension == 'glb') {
      if (bytes.length < 20) throw const FormatException('Invalid GLB file.');
      final header = ByteData.sublistView(bytes);
      if (header.getUint32(0, Endian.little) != 0x46546c67 ||
          header.getUint32(4, Endian.little) != 2 ||
          header.getUint32(8, Endian.little) != bytes.length ||
          header.getUint32(16, Endian.little) != 0x4e4f534a) {
        throw const FormatException('Expected a glTF 2.0 GLB model.');
      }
      final end = 20 + header.getUint32(12, Endian.little);
      if (end > bytes.length) throw const FormatException('Invalid GLB data.');
      final json = jsonDecode(utf8.decode(bytes.sublist(20, end))) as Map;
      for (final key in ['buffers', 'images']) {
        for (final item in (json[key] as List? ?? [])) {
          final uri = item['uri'] as String?;
          if (uri != null && !uri.startsWith('data:')) {
            throw const FormatException(
              'GLB must include its textures and buffers. Export as a packed GLB or import a .gltf file.',
            );
          }
        }
      }
      return bytes;
    }
    if (extension != 'gltf') {
      throw const FormatException('Choose a .glb or .gltf model.');
    }
    final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    if (json['asset']?['version'] != '2.0') {
      throw const FormatException('Only glTF 2.0 models are supported.');
    }
    var total = bytes.length;
    final root =
        '${await file.parent.resolveSymbolicLinks()}${Platform.pathSeparator}';
    for (final key in ['buffers', 'images']) {
      for (final item in (json[key] as List? ?? [])) {
        final value = item['uri'] as String?;
        if (value == null || value.startsWith('data:')) continue;
        final uri = Uri.parse(value);
        if (uri.hasScheme ||
            uri.hasAuthority ||
            uri.hasQuery ||
            uri.hasFragment) {
          throw const FormatException(
            'Model dependencies must be local relative files.',
          );
        }
        final dependency = File.fromUri(file.absolute.uri.resolveUri(uri));
        final resolved = await dependency.resolveSymbolicLinks();
        if (!resolved.startsWith(root)) {
          throw const FormatException(
            'Model dependencies must be inside the model folder.',
          );
        }
        total += await dependency.length();
        if (total > maxBytes) {
          throw const FormatException(
            'Model and textures must be smaller than 100 MB.',
          );
        }
        final mime = key == 'buffers'
            ? 'application/octet-stream'
            : switch (resolved.split('.').last.toLowerCase()) {
                'png' => 'image/png',
                'jpg' || 'jpeg' => 'image/jpeg',
                'webp' => 'image/webp',
                'ktx2' => 'image/ktx2',
                _ => 'application/octet-stream',
              };
        item['uri'] =
            'data:$mime;base64,${base64Encode(await dependency.readAsBytes())}';
      }
    }
    return Uint8List.fromList(utf8.encode(jsonEncode(json)));
  }
}
