import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

Future<void> openLocalPath(String path) async {
  if (path.isEmpty) return;
  if (Platform.isWindows) {
    await Process.start('explorer', [path]);
    return;
  }
  try {
    final uri = Uri.file(path);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  } catch (_) {
    // 移动端未注册文件关联或无默认应用时不抛异常
  }
}

Future<void> openParentFolder(String filePath) async {
  final dir = File(filePath).parent.path;
  await openLocalPath(dir);
}
