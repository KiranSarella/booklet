import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:booklet/ui/base_vm.dart';

class BookletFile {
  static const _extension = 'booklet';
  static const _manifestName = 'content.json';

  static Future<bool> save(
    BaseVM viewModel, {
    bool saveAs = false,
  }) async {
    var packagePath = saveAs ? null : viewModel.documentPath;
    if (packagePath == null) {
      final location = await getSaveLocation(suggestedName: 'Untitled.booklet');
      if (location == null) {
        return false;
      }
      packagePath = location.path;
    }

    final normalizedPath = packagePath.endsWith('.$_extension')
        ? packagePath
        : '$packagePath.$_extension';
    final package = Directory(normalizedPath);
    await package.create(recursive: true);
    await for (final entry in package.list()) {
      if (entry is Directory &&
          (entry.path.endsWith('/media') ||
              entry.path.endsWith('/custom_components') ||
              entry.path.endsWith('/metadata'))) {
        continue;
      }
      if (entry is File) {
        await entry.delete();
      }
    }
    await Directory('${package.path}/media').create(recursive: true);
    await Directory('${package.path}/custom_components')
        .create(recursive: true);
    await Directory('${package.path}/metadata').create(recursive: true);
    final contents = const JsonEncoder.withIndent('  ')
        .convert(viewModel.toJson());
    await File('${package.path}/$_manifestName').writeAsString(contents);
    viewModel.setDocumentPath(package.path);
    return true;
  }

  static Future<bool> saveAs(BaseVM viewModel) =>
      save(viewModel, saveAs: true);

  static Future<bool> open(BaseVM viewModel) async {
    final file = await openFile();
    if (file == null) {
      return false;
    }

    final selectedPath = file.path;
    final manifest = FileSystemEntity.isDirectorySync(selectedPath)
        ? File('$selectedPath/$_manifestName')
        : File(selectedPath);
    final json = jsonDecode(await manifest.readAsString());
    if (json is! Map) {
      throw const FormatException('Invalid booklet document');
    }
    viewModel.loadJson(Map<String, dynamic>.from(json));
    viewModel.setDocumentPath(
      FileSystemEntity.isDirectorySync(selectedPath) ? selectedPath : null,
    );
    return true;
  }
}
