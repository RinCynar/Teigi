import 'dart:async';
import 'dart:io';

import 'package:teigi/core/ffmpeg/ffmpeg_command_builder.dart';
import 'package:teigi/core/ffmpeg/progress_parser.dart';
import 'package:teigi/core/models/conversion_task.dart';

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
    final command = const FfmpegCommandBuilder().build(task);
    final outputPath = command.outputPath;
    final args = command.args;

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

  List<String> buildArgs(ConversionTask task, String outputPath) {
    return const FfmpegCommandBuilder().buildArgs(task, outputPath);
  }
}
