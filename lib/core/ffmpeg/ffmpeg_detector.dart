import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:teigi/core/ffmpeg/engine/ffmpeg_engine.dart';

/// 负责在启动时检测 ffmpeg 是否可用。
///
/// 检测顺序：
/// 1. 用户明确保存的自定义路径
/// 2. 安装目录内置的 `data/ffmpeg`
/// 3. 系统 PATH（遍历 `PATH` 环境变量定位可执行文件）
class FfmpegDetector {
  FfmpegDetector({
    Logger? logger,
    Future<String?> Function()? bundledPathResolver,
    Future<String?> Function()? pathResolver,
    Future<FfmpegEngineStatus> Function(String path)? probe,
    Duration probeTimeout = const Duration(seconds: 10),
  }) : this._fromResolvers(
         logger ?? Logger(),
         bundledPathResolver,
         pathResolver,
         probe,
         probeTimeout,
       );

  FfmpegDetector._fromResolvers(
    this._logger,
    this._bundledPathResolver,
    this._pathResolver,
    this._probeOverride,
    this._probeTimeout,
  );

  final Logger _logger;
  final Future<String?> Function()? _bundledPathResolver;
  final Future<String?> Function()? _pathResolver;
  final Future<FfmpegEngineStatus> Function(String path)? _probeOverride;
  final Duration _probeTimeout;

  /// 检测 ffmpeg。返回信息包含实际使用的路径与版本号。
  Future<FfmpegEngineStatus> detect({String? customPath}) async {
    // An explicit user choice must win over every automatic source.
    final custom = customPath?.trim();
    if (custom != null && custom.isNotEmpty) {
      final info = (await _probe(custom)).withSource(FfmpegEngineSource.custom);
      if (info.isReady) {
        _logger.i(
          '使用自定义 ffmpeg 路径: ${info.resolvedExecutablePath} (${info.version})',
        );
        return info.withRequestedCustomPath(custom);
      }
      _logger.w('自定义 ffmpeg 路径无效: $custom (${info.errorMessage ?? '未知原因'})');

      final fallback = await _detectAutomatic();
      if (fallback != null && fallback.isReady) {
        return fallback.withRequestedCustomPath(custom);
      }
      return info.withRequestedCustomPath(custom);
    }

    return await _detectAutomatic() ?? FfmpegEngineStatus.unavailable;
  }

  Future<FfmpegEngineStatus?> _detectAutomatic() async {
    // Prefer the copy shipped by the installer over whatever happens to be
    // installed in the user's PATH.
    final bundled = await _findBundled();
    if (bundled != null) {
      final info = (await _probe(
        bundled,
      )).withSource(FfmpegEngineSource.bundled);
      if (info.isReady) {
        _logger.i(
          '使用内置 ffmpeg: ${info.resolvedExecutablePath} (${info.version})',
        );
        return info;
      }
    }

    // Fall back to PATH only when no higher-priority source is usable.
    final inPath = await _findInPath();
    if (inPath != null) {
      final info = (await _probe(
        inPath,
      )).withSource(FfmpegEngineSource.systemPath);
      if (info.isReady) {
        _logger.i(
          '在 PATH 中发现 ffmpeg: ${info.resolvedExecutablePath} (${info.version})',
        );
        return info;
      }
    }

    _logger.w('未找到 ffmpeg');
    return null;
  }

  /// 在软件安装目录中查找内置的 `data/ffmpeg/ffmpeg`。
  Future<String?> _findBundled() async {
    if (_bundledPathResolver != null) return _bundledPathResolver();

    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = <String>[
      p.join(
        exeDir,
        'data',
        'ffmpeg',
        Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg',
      ),
      p.join(
        Directory.current.path,
        'data',
        'ffmpeg',
        Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg',
      ),
    ];
    for (final c in candidates) {
      if (File(c).existsSync()) return c;
    }
    return null;
  }

  /// 在 PATH 中查找 ffmpeg 可执行文件路径。
  ///
  /// 不依赖 `where` / `which` 等外部命令，直接在 Dart 层遍历 `PATH`
  /// 环境变量拼接候选路径并逐个探测，避免外部命令缺失带来的不确定性。
  Future<String?> _findInPath() async {
    if (_pathResolver != null) return _pathResolver();

    final pathVar = Platform.environment['PATH'];
    if (pathVar == null || pathVar.isEmpty) return null;

    final separator = Platform.isWindows ? ';' : ':';
    final extensions = Platform.isWindows
        ? _windowsExecutableExtensions()
        : const <String>[''];

    for (final dir in pathVar.split(separator)) {
      final directory = dir.trim();
      if (directory.isEmpty) continue;
      for (final ext in extensions) {
        final candidate = p.join(directory, 'ffmpeg$ext');
        if (File(candidate).existsSync()) return candidate;
      }
    }
    return null;
  }

  /// Windows 可执行文件扩展名列表，取自 `PATHEXT`，找不到时用常见默认值。
  List<String> _windowsExecutableExtensions() {
    final pathext = Platform.environment['PATHEXT'];
    if (pathext == null || pathext.isEmpty) {
      return const ['.exe', '.cmd', '.bat', '.com'];
    }
    return pathext
        .split(';')
        .where((e) => e.trim().isNotEmpty)
        .map((e) => e.trim().toLowerCase())
        .toList();
  }

  /// 校验路径并获取版本号。
  Future<FfmpegEngineStatus> _probe(String path) async {
    if (_probeOverride != null) return _probeOverride(path);

    if (!File(path).existsSync()) {
      return FfmpegEngineStatus(isReady: false, errorMessage: '文件不存在：$path');
    }

    Process? process;
    try {
      process = await Process.start(path, ['-version']);
      final stdoutFuture = process.stdout.transform(utf8.decoder).join();
      final stderrFuture = process.stderr.transform(utf8.decoder).join();
      final exitCode = await process.exitCode.timeout(_probeTimeout);

      if (exitCode == 0) {
        final stdout = await stdoutFuture;
        await stderrFuture;
        final firstLine = stdout.trim().split('\n').first;
        final version = _parseVersion(firstLine);
        return FfmpegEngineStatus(
          isReady: true,
          version: version,
          resolvedExecutablePath: path,
        );
      }

      await stderrFuture;
      return FfmpegEngineStatus(
        isReady: false,
        errorMessage: '无法运行 ffmpeg：$path（退出码 $exitCode）',
      );
    } on TimeoutException {
      process?.kill();
      return FfmpegEngineStatus(isReady: false, errorMessage: '检测超时：$path');
    } catch (e) {
      _logger.w('探测 ffmpeg 失败 ($path): $e');
      return FfmpegEngineStatus(isReady: false, errorMessage: '无法运行 ffmpeg：$e');
    }
  }

  /// 从 `ffmpeg version X.Y.Z ...` 首行解析版本号。
  String _parseVersion(String firstLine) {
    final match = RegExp(r'ffmpeg version ([\w.\-+]+)').firstMatch(firstLine);
    return match?.group(1) ?? firstLine;
  }
}
