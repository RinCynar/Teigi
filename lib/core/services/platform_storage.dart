import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:teigi/core/utils/open_path.dart';
import 'package:teigi/core/utils/platform_info.dart';

/// 跨平台存储与系统媒体服务：
/// - 默认输出目录计算（Android 优先输出至公共存储 Download/Teigi）
/// - 转码完成后的 MediaStore 扫描
/// - 调用系统播放器/查看器打开文件
/// - 调用系统分享面板（Share Sheet）
class PlatformStorage {
  static const _channel = MethodChannel('com.example.teigi/platform');

  /// 获取平台的默认输出目录。
  /// Android 下默认为公共存储 Download/Teigi；桌面端默认为空（表示与源文件同目录）。
  static Future<String> getDefaultOutputDirectory() async {
    if (!isAndroid) return '';

    try {
      const defaultDownload = '/storage/emulated/0/Download/Teigi';
      final dir = Directory(defaultDownload);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir.path;
    } catch (_) {
      try {
        final downloadsDir = await getDownloadsDirectory();
        if (downloadsDir != null) {
          final teigiDir = Directory('${downloadsDir.path}/Teigi');
          if (!await teigiDir.exists()) {
            await teigiDir.create(recursive: true);
          }
          return teigiDir.path;
        }
      } catch (_) {}

      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final teigiDir = Directory('${extDir.path}/Teigi');
          if (!await teigiDir.exists()) {
            await teigiDir.create(recursive: true);
          }
          return teigiDir.path;
        }
      } catch (_) {}

      return '';
    }
  }

  /// 在 Android 上通知系统 MediaStore 扫描新文件，使其立即在相册与媒体库中可见。
  static Future<void> scanMediaFile(String filePath) async {
    if (!isAndroid || filePath.isEmpty) return;
    try {
      await _channel.invokeMethod('scanMediaFile', {'path': filePath});
    } catch (_) {}
  }

  /// 使用系统默认关联应用打开媒体文件。
  static Future<void> openFile(String filePath) async {
    if (filePath.isEmpty) return;
    if (isAndroid) {
      try {
        await _channel.invokeMethod('openFile', {'path': filePath});
        return;
      } catch (_) {}
    }
    await openLocalPath(filePath);
  }

  /// 调用系统分享面板（Share Sheet）分享文件。
  static Future<void> shareFile(String filePath) async {
    if (filePath.isEmpty) return;
    if (isAndroid) {
      try {
        await _channel.invokeMethod('shareFile', {'path': filePath});
        return;
      } catch (_) {}
    }
    await openLocalPath(filePath);
  }
}
