import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';

/// The portable .booklet container. Editing happens in a private workspace;
/// only a complete, closed archive replaces the user's document.
class BookletArchive {
  static const _macSaveChannel = MethodChannel('booklet/document_file');

  static const maxExpandedBytes = 2 * 1024 * 1024 * 1024;

  static Future<Directory> createWorkspace({String? sourceDirectory}) async {
    final workspace = await Directory.systemTemp.createTemp(
      'booklet_document_',
    );
    try {
      if (sourceDirectory != null) {
        await for (final entity in Directory(
          sourceDirectory,
        ).list(recursive: true, followLinks: false)) {
          final relative = entity.path.substring(sourceDirectory.length + 1);
          final target = '${workspace.path}/$relative';
          if (entity is Directory) {
            await Directory(target).create(recursive: true);
          } else if (entity is File) {
            await File(target).parent.create(recursive: true);
            await entity.copy(target);
          } else {
            throw const FormatException(
              'Linked files are not supported in booklet packages.',
            );
          }
        }
      }
      return workspace;
    } catch (_) {
      await workspace.delete(recursive: true);
      rethrow;
    }
  }

  static Future<({Directory workspace, String packagePath})> open(
    String filePath,
  ) async {
    final workspace = await createWorkspace();
    final destination = workspace.path;
    try {
      final packagePath = await Isolate.run(() {
        final input = InputFileStream(filePath);
        try {
          final archive = ZipDecoder().decodeStream(input, verify: true);
          if (archive.length > 50000) {
            throw const FormatException('Too many booklet entries.');
          }
          for (final entry in archive) {
            final name = entry.name.replaceAll(r'\', '/');
            if (entry.isSymbolicLink ||
                name.startsWith('/') ||
                name.contains(':') ||
                name.split('/').contains('..')) {
              throw const FormatException('Invalid booklet entry path.');
            }
          }
          extractArchiveToDiskSync(
            archive,
            destination,
            maxSize: maxExpandedBytes,
          );
        } finally {
          input.closeSync();
        }
        var package = Directory(destination);
        if (!File('$destination/content.json').existsSync()) {
          final candidates = package
              .listSync()
              .whereType<Directory>()
              .where((dir) => File('${dir.path}/content.json').existsSync())
              .toList();
          if (candidates.length != 1) {
            throw const FormatException('Missing booklet manifest.');
          }
          package = candidates.single;
        }
        final manifest = jsonDecode(
          File('${package.path}/content.json').readAsStringSync(),
        );
        if (manifest is! Map || manifest['navigation'] is! List) {
          throw const FormatException('Invalid booklet manifest.');
        }
        return package.path;
      });
      return (workspace: workspace, packagePath: packagePath);
    } catch (_) {
      await workspace.delete(recursive: true);
      rethrow;
    }
  }

  static Future<void> write(String packagePath, String filePath) async {
    final destination = File(filePath).absolute.path;
    String? replacementDirectory;
    if (Platform.isMacOS) {
      try {
        replacementDirectory = await _macSaveChannel.invokeMethod<String>(
          'prepareSave',
          {'destination': destination},
        );
      } on MissingPluginException {
        // Headless Flutter tests have no macOS runner.
      }
    }
    final temporary = replacementDirectory == null
        ? '$destination.${const Uuid().v4()}.tmp'
        : '$replacementDirectory/document.tmp';
    String? legacyBackup;
    try {
      await Isolate.run(() async {
        if (!File('$packagePath/content.json').existsSync()) {
          throw const FormatException('Missing booklet manifest.');
        }
        var size = 0;
        for (final entity in Directory(
          packagePath,
        ).listSync(recursive: true, followLinks: false)) {
          if (entity is Link) {
            throw const FormatException('Linked files are not supported.');
          }
          if (entity is File) size += entity.lengthSync();
          if (size > maxExpandedBytes) {
            throw const FormatException('Booklet exceeds 2 GB.');
          }
        }
        await File(temporary).parent.create(recursive: true);
        final encoder = ZipFileEncoder();
        encoder.create(temporary);
        try {
          await encoder.addDirectory(
            Directory(packagePath),
            includeDirName: false,
            followLinks: false,
          );
        } finally {
          await encoder.close();
        }
        // Flush the finished container before replacing the last good version.
        final handle = await File(temporary).open(mode: FileMode.append);
        try {
          await handle.flush();
        } finally {
          await handle.close();
        }
      });
      if (replacementDirectory != null) {
        await _macSaveChannel.invokeMethod<void>('commitSave', {
          'source': temporary,
          'destination': destination,
        });
        return;
      }
      if (await Directory(destination).exists()) {
        legacyBackup = '$destination.legacy-${const Uuid().v4()}';
        await Directory(destination).rename(legacyBackup);
      }
      try {
        await File(temporary).rename(destination);
      } catch (_) {
        if (legacyBackup != null) {
          await Directory(legacyBackup).rename(destination);
        }
        rethrow;
      }
    } finally {
      final staged = File(temporary);
      if (await staged.exists()) await staged.delete();
      if (replacementDirectory != null) {
        final directory = Directory(replacementDirectory);
        if (await directory.exists()) await directory.delete(recursive: true);
      }
    }
  }
}
