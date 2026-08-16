import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

Future<void> openLocalPath(String path) async {
  if (path.isEmpty) return;
  if (Platform.isWindows) {
    await Process.start('explorer', [path]);
    return;
  }
  await launchUrl(Uri.file(path));
}

Future<void> openParentFolder(String filePath) async {
  final dir = File(filePath).parent.path;
  await openLocalPath(dir);
}
