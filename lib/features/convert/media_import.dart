import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:teigi/core/models/media_file.dart';

/// Collects files from pickers and drops. Does not talk to FFmpeg.
class MediaImport {
  const MediaImport();

  Future<List<MediaFile>> pickFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return const [];
    return [
      for (final f in result.files)
        if (f.path != null) MediaFile(path: f.path!),
    ];
  }

  Future<List<MediaFile>> pickFolder({String? dialogTitle}) async {
    final path = await FilePicker.getDirectoryPath(dialogTitle: dialogTitle);
    if (path == null) return const [];
    return fromDirectory(path);
  }

  Future<List<MediaFile>> fromDropped(List<DropItem> items) async {
    final files = <MediaFile>[];
    for (final item in items) {
      if (item.path.isEmpty) continue;
      files.addAll(await fromPath(item.path));
    }
    return files;
  }

  Future<List<MediaFile>> fromPath(String path) async {
    final type = FileSystemEntity.typeSync(path);
    if (type == FileSystemEntityType.directory) {
      return fromDirectory(path);
    }
    if (type == FileSystemEntityType.file) {
      return [MediaFile(path: path)];
    }
    return const [];
  }

  Future<List<MediaFile>> fromDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return const [];
    final entries = await dir.list(recursive: false).toList();
    return [
      for (final e in entries)
        if (e is File) MediaFile(path: e.path),
    ];
  }
}
