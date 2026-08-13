import 'dart:async';
import 'dart:io';

import 'package:teigi/core/ffmpeg/progress_parser.dart';
import 'package:teigi/core/models/conversion_task.dart';
import 'package:teigi/core/utils/file_naming.dart';

/// ffmpeg 命令执行结果。
class FfmpegResult {
  final int exitCode;
  final String? outputPath;
  final String? error;

  const FfmpegResult({
    required this.exitCode,
    this.outputPath,
    this.error,
  });

  bool get isSuccess => exitCode == 0;
}

/// 一次转换的进度回调。
typedef OnProgress = void Function(ProgressUpdate update);

/// 一次转换的状态回调（输出路径/错误信息等）。
typedef OnOutput = void Function(String line);

/// 进程启动回调（用于引擎追踪/终止进程）。
typedef OnProcessStart = void Function(Process process);

/// 负责构造并执行 ffmpeg 命令，解析进度。
class FfmpegRunner {
  final String ffmpegPath;

  FfmpegRunner({required this.ffmpegPath});

  /// 执行一次转换。
  ///
  /// [task] 提供源文件、目标格式与选项；
  /// 返回输出文件路径与退出码。
  Future<FfmpegResult> convert(
    ConversionTask task, {
    OnProgress? onProgress,
    OnOutput? onOutput,
    OnProcessStart? onProcessStart,
  }) async {
    final options = task.options;
    final target = task.targetFormat;
    if (target == null || target.isEmpty) {
      throw ArgumentError('任务未指定目标格式：${task.source.path}');
    }

    final outputPath = FileNaming.buildOutputPath(
      source: task.source,
      targetExtension: target,
      outputDirectory: options.outputDirectory,
      template: options.fileNameTemplate,
      overwritePolicy: options.overwritePolicy,
    );

    final args = buildArgs(task, outputPath);

    final process = await Process.start(ffmpegPath, args);
    onProcessStart?.call(process);

    // ffmpeg 进度在 stderr 输出。
    final parser = ProgressParser();
    String buffer = '';
    final stderrCompleter = Completer<void>();

    process.stderr.listen((chunk) {
      buffer += decodeChunkLines(chunk).join('\n');
      // 按行处理缓冲。
      while (true) {
        final nl = buffer.indexOf('\n');
        if (nl < 0) break;
        final line = buffer.substring(0, nl).trimRight();
        buffer = buffer.substring(nl + 1);
        _handleLine(line, parser, onProgress, onOutput);
      }
    }, onDone: () {
      if (buffer.isNotEmpty) {
        _handleLine(buffer.trimRight(), parser, onProgress, onOutput);
      }
      stderrCompleter.complete();
    });

    // 等待退出。
    final exitCode = await process.exitCode;
    await stderrCompleter.future;

    if (exitCode != 0) {
      return FfmpegResult(
        exitCode: exitCode,
        outputPath: outputPath,
        error: 'ffmpeg 退出码 $exitCode',
      );
    }

    return FfmpegResult(exitCode: 0, outputPath: outputPath);
  }

  void _handleLine(
    String line,
    ProgressParser parser,
    OnProgress? onProgress,
    OnOutput? onOutput,
  ) {
    parser.parseDurationLine(line);
    final output = parser.parseOutputPath(line);
    if (output != null) onOutput?.call(output);
    final update = parser.parseProgressLine(line);
    if (update != null) onProgress?.call(update);
  }

  /// 构造 ffmpeg 命令行参数。
  ///
  /// 始终先使用 `-y` 允许覆盖，实际冲突策略由 [FileNaming] 处理
  /// （keepBoth 时输出路径已避免冲突）。
  List<String> buildArgs(ConversionTask task, String outputPath) {
    final options = task.options;
    final args = <String>['-y', '-hide_banner'];

    // 输入。
    args.addAll(['-i', task.source.path]);

    // 全局：线程数。
    if (options.threads > 0) {
      args.addAll(['-threads', '${options.threads}']);
    }

    // 全局：保留输入元数据（标签信息）。
    args.addAll(['-map_metadata', '0']);

    // 视频流处理。
    if (!options.copyVideo) {
      var encoder = options.videoEncoder ?? _defaultVideoEncoder(task);
      if (options.hardwareAccel && encoder.isNotEmpty) {
        encoder = _hardwareEncoder(encoder);
      }
      if (encoder.isNotEmpty) {
        args.addAll(['-c:v', encoder]);
      }
      if (options.crf != null) {
        args.addAll(['-crf', '${options.crf}']);
      }
      if (options.resolution != null) {
        args.addAll(['-vf', 'scale=${options.resolution}']);
      }
      if (options.maxResolution != null) {
        // 图片最大分辨率：等比缩小到指定范围内，不放大。
        final parts = options.maxResolution!.split('x');
        if (parts.length == 2) {
          final w = int.tryParse(parts[0]);
          final h = int.tryParse(parts[1]);
          if (w != null && h != null && w > 0 && h > 0) {
            final filter =
                'scale=min(iw\\,$w)\\,min(ih\\,$h):force_original_aspect_ratio=decrease';
            args.addAll(['-vf', filter]);
          }
        }
      }
      if (options.frameRate != null) {
        args.addAll(['-r', '${options.frameRate}']);
      }
      if (options.pixelFormat != null) {
        args.addAll(['-pix_fmt', options.pixelFormat!]);
      }
    } else {
      args.addAll(['-c:v', 'copy']);
    }

    // 音频流处理。
    if (!options.copyAudio) {
      final encoder = options.audioEncoder ?? _defaultAudioEncoder(task);
      if (encoder.isNotEmpty) {
        args.addAll(['-c:a', encoder]);
      }
      if (options.bitrateKbps != null) {
        args.addAll(['-b:a', '${options.bitrateKbps}k']);
      }
      if (options.sampleRate != null) {
        args.addAll(['-ar', '${options.sampleRate}']);
      }
      if (options.channels != null) {
        args.addAll(['-ac', '${options.channels}']);
      }
      if (options.volume != null) {
        args.addAll(['-af', 'volume=${options.volume! / 100}']);
      }
    } else {
      args.addAll(['-c:a', 'copy']);
    }

    // 输出。
    args.add(outputPath);
    return args;
  }

  /// 根据目标格式选择默认视频编码器。
  String _defaultVideoEncoder(ConversionTask task) {
    final target = task.targetFormat ?? '';
    final fromTarget = _formatEncoders[target];
    if (fromTarget != null) return fromTarget;
    return '';
  }

  /// 硬件加速时将 CPU 编码器映射为对应的硬件编码器。
  /// 优先 NVIDIA NVENC；未知编码器保持原样。
  String _hardwareEncoder(String encoder) {
    final hw = _hwEncoders[encoder];
    return hw ?? encoder;
  }

  /// 根据目标格式选择默认音频编码器。
  String _defaultAudioEncoder(ConversionTask task) {
    final target = task.targetFormat ?? '';
    final fromTarget = _audioFormatEncoders[target];
    if (fromTarget != null) return fromTarget;
    return '';
  }
}

/// 常见视频格式默认编码器。
const Map<String, String> _formatEncoders = {
  'mp4': 'libx264',
  'mkv': 'libx265',
  'webm': 'libvpx-vp9',
  'avi': 'mpeg4',
  'mov': 'libx264',
  'hevc': 'libx265',
  'gif': '',
  'flv': 'flv1',
  'm4v': 'libx264',
};

/// CPU 编码器 → 硬件加速编码器映射。
const Map<String, String> _hwEncoders = {
  'libx264': 'h264_nvenc',
  'libx265': 'hevc_nvenc',
  'libvpx-vp9': 'vp9_qsv',
  'mpeg4': 'mpeg4_qsv',
};

/// 常见音频格式默认编码器。
const Map<String, String> _audioFormatEncoders = {
  'mp3': 'libmp3lame',
  'aac': 'aac',
  'flac': 'flac',
  'wav': 'pcm_s16le',
  'opus': 'libopus',
  'ogg': 'libvorbis',
  'm4a': 'aac',
  'wma': 'wmav2',
  'ac3': 'ac3',
  'amr': 'libopencore_amrnb',
};
