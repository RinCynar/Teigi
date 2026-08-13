import 'dart:io';

import 'package:logger/logger.dart';

/// ffmpeg 可用性检测结果。
class FfmpegInfo {
  final String path;
  final String version;

  const FfmpegInfo({required this.path, required this.version});

  bool get isAvailable => path.isNotEmpty;

  static const FfmpegInfo unavailable = FfmpegInfo(path: '', version: '');

  @override
  String toString() => 'FfmpegInfo(path: $path, version: $version)';
}

/// 负责在启动时检测 ffmpeg 是否可用。
///
/// 检测顺序：
/// 1. 用户保存的自定义路径（优先级最高）
/// 2. 系统 PATH（`where ffmpeg` / `which ffmpeg`）
class FfmpegDetector {
  FfmpegDetector({Logger? logger}) : _logger = logger ?? Logger();

  final Logger _logger;

  /// 检测 ffmpeg。返回信息包含路径与版本号；找不到时返回
  /// [FfmpegInfo.unavailable]。
  Future<FfmpegInfo> detect({String? customPath}) async {
    // 1. 自定义路径优先。
    if (customPath != null && customPath.isNotEmpty) {
      final info = await _probe(customPath);
      if (info.isAvailable) {
        _logger.i('使用自定义 ffmpeg 路径: ${info.path} (${info.version})');
        return info;
      }
      _logger.w('自定义 ffmpeg 路径无效: $customPath');
    }

    // 2. PATH 中查找。
    final inPath = await _findInPath();
    if (inPath != null) {
      final info = await _probe(inPath);
      if (info.isAvailable) {
        _logger.i('在 PATH 中发现 ffmpeg: ${info.path} (${info.version})');
        return info;
      }
    }

    _logger.w('未找到 ffmpeg');
    return FfmpegInfo.unavailable;
  }

  /// 在 PATH 中查找 ffmpeg 可执行文件路径。
  Future<String?> _findInPath() async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('where', ['ffmpeg']);
        if (result.exitCode == 0) {
          final lines = (result.stdout as String).trim().split('\n');
          for (final line in lines) {
            final path = line.trim();
            if (path.isNotEmpty && File(path).existsSync()) return path;
          }
        }
      } else {
        final result = await Process.run('which', ['ffmpeg']);
        if (result.exitCode == 0) {
          final path = (result.stdout as String).trim();
          if (path.isNotEmpty && File(path).existsSync()) return path;
        }
      }
    } catch (e) {
      _logger.w('PATH 查找失败: $e');
    }
    return null;
  }

  /// 校验路径并获取版本号。
  Future<FfmpegInfo> _probe(String path) async {
    if (!File(path).existsSync()) return FfmpegInfo.unavailable;
    try {
      final result = await Process.run(path, ['-version']);
      if (result.exitCode == 0) {
        final firstLine = (result.stdout as String).trim().split('\n').first;
        final version = _parseVersion(firstLine);
        return FfmpegInfo(path: path, version: version);
      }
    } catch (e) {
      _logger.w('探测 ffmpeg 失败 ($path): $e');
    }
    return FfmpegInfo.unavailable;
  }

  /// 从 `ffmpeg version X.Y.Z ...` 首行解析版本号。
  String _parseVersion(String firstLine) {
    final match = RegExp(r'ffmpeg version ([\w.\-+]+)').firstMatch(firstLine);
    return match?.group(1) ?? firstLine;
  }
}
