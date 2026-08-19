import 'dart:async';
import 'dart:io';

import 'package:teigi/core/ffmpeg/ffmpeg_command.dart';
import 'package:teigi/core/ffmpeg/ffmpeg_detector.dart';
import 'package:teigi/core/ffmpeg/engine/ffmpeg_engine.dart';
import 'package:teigi/core/ffmpeg/progress_parser.dart';

/// Desktop implementation backed by the local FFmpeg executable and Process.
class DesktopFfmpegEngine implements FfmpegEngine {
  DesktopFfmpegEngine({FfmpegDetector? detector})
    : _detector = detector ?? FfmpegDetector();

  final FfmpegDetector _detector;
  String? _resolvedExecutablePath;

  @override
  FfmpegEngineCapabilities get capabilities => const FfmpegEngineCapabilities(
    supportsCustomExecutablePath: true,
    supportsHardwareAccelProbe: false,
    supportsConcurrentSessions: true,
  );

  @override
  Future<FfmpegEngineStatus> detect({String? customExecutablePath}) async {
    final status = await _detector.detect(customPath: customExecutablePath);
    _resolvedExecutablePath = status.resolvedExecutablePath;
    return status;
  }

  @override
  FfmpegTaskHandle run(FfmpegCommand command) {
    return _DesktopFfmpegTaskHandle(
      executablePath: _resolvedExecutablePath,
      command: command,
    );
  }
}

class _DesktopFfmpegTaskHandle implements FfmpegTaskHandle {
  _DesktopFfmpegTaskHandle({
    required this.executablePath,
    required this.command,
  }) {
    unawaited(_start());
  }

  final String? executablePath;
  final FfmpegCommand command;
  final StreamController<ProgressUpdate> _progressController =
      StreamController<ProgressUpdate>.broadcast();
  final StreamController<String> _outputController =
      StreamController<String>.broadcast();
  final StreamController<FfmpegTaskState> _stateController =
      StreamController<FfmpegTaskState>.broadcast();
  final Completer<FfmpegResult> _resultCompleter = Completer<FfmpegResult>();

  Process? _process;
  bool _cancelRequested = false;
  bool _outputExistedBeforeStart = false;

  @override
  Stream<ProgressUpdate> get progress => _progressController.stream;

  @override
  Stream<String> get outputPaths => _outputController.stream;

  @override
  Stream<FfmpegTaskState> get states => _stateController.stream;

  @override
  Future<FfmpegResult> get result => _resultCompleter.future;

  @override
  Future<void> cancel() async {
    _cancelRequested = true;
    final process = _process;
    if (process == null) return;
    await _terminateProcess(process);
  }

  Future<void> _start() async {
    _emitState(FfmpegTaskState.starting);
    final path = executablePath;
    if (path == null || path.isEmpty) {
      _emitState(FfmpegTaskState.failed);
      _completeResult(
        const FfmpegResult(
          exitCode: -1,
          state: FfmpegTaskState.failed,
          error: 'ffmpeg 未就绪',
        ),
      );
      await _progressController.close();
      await _outputController.close();
      await _stateController.close();
      return;
    }

    try {
      _outputExistedBeforeStart = File(command.outputPath).existsSync();
      final process = await Process.start(path, command.args);
      _process = process;
      _emitState(FfmpegTaskState.running);
      if (_cancelRequested) {
        await _terminateProcess(process);
      }

      final parser = ProgressParser();
      String buffer = '';
      final stderrBuffer = StringBuffer();
      String? outputPath = command.outputPath;
      final stderrCompleter = Completer<void>();

      process.stderr.listen(
        (chunk) {
          final lines = decodeChunkLines(chunk);
          stderrBuffer.write(lines.join('\n'));
          buffer += lines.join('\n');
          while (true) {
            final nl = buffer.indexOf('\n');
            if (nl < 0) break;
            final line = buffer.substring(0, nl).trimRight();
            buffer = buffer.substring(nl + 1);
            outputPath = _handleLine(line, parser, outputPath);
          }
        },
        onDone: () {
          if (buffer.isNotEmpty) {
            outputPath = _handleLine(buffer.trimRight(), parser, outputPath);
          }
          if (!stderrCompleter.isCompleted) stderrCompleter.complete();
        },
        onError: (Object _) {
          if (!stderrCompleter.isCompleted) stderrCompleter.complete();
        },
      );

      final exitCode = await process.exitCode;
      await stderrCompleter.future;

      if (exitCode != 0) {
        await _removePartialOutputIfNeeded();
        final state = _cancelRequested
            ? FfmpegTaskState.cancelled
            : FfmpegTaskState.failed;
        _emitState(state);
        _completeResult(
          FfmpegResult(
            exitCode: exitCode,
            state: state,
            outputPath: command.outputPath,
            error: _cancelRequested ? 'ffmpeg 已取消' : 'ffmpeg 退出码 $exitCode',
            stderr: stderrBuffer.toString(),
          ),
        );
      } else {
        _emitState(FfmpegTaskState.completed);
        _completeResult(
          FfmpegResult(
            exitCode: 0,
            state: FfmpegTaskState.completed,
            outputPath: command.outputPath,
            stderr: stderrBuffer.toString(),
          ),
        );
      }
    } catch (error) {
      await _removePartialOutputIfNeeded();
      final state = _cancelRequested
          ? FfmpegTaskState.cancelled
          : FfmpegTaskState.failed;
      _emitState(state);
      _completeResult(
        FfmpegResult(
          exitCode: -1,
          state: state,
          outputPath: command.outputPath,
          error: error.toString(),
        ),
      );
    } finally {
      await _progressController.close();
      await _outputController.close();
      await _stateController.close();
    }
  }

  Future<void> _terminateProcess(Process process) async {
    // Windows spawns may leave orphaned child processes behind, so kill the
    // whole tree. On POSIX we start ffmpeg directly (no shell wrapper), so a
    // plain SIGTERM is enough: ffmpeg shuts down gracefully and finalizes the
    // output file instead of being force-killed.
    if (Platform.isWindows) {
      try {
        await Process.run('taskkill', ['/T', '/F', '/PID', '${process.pid}']);
        return;
      } catch (_) {
        // Fall through to the best-effort local kill.
      }
    }

    try {
      process.kill(ProcessSignal.sigterm);
    } catch (_) {}
  }

  Future<void> _removePartialOutputIfNeeded() async {
    if (_outputExistedBeforeStart) return;
    try {
      final file = File(command.outputPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  String? _handleLine(String line, ProgressParser parser, String? outputPath) {
    parser.parseDurationLine(line);
    final output = parser.parseOutputPath(line);
    if (output != null) {
      outputPath = output;
      if (!_outputController.isClosed) _outputController.add(output);
    }
    final update = parser.parseProgressLine(line);
    if (update != null && !_progressController.isClosed) {
      _progressController.add(update);
    }
    return outputPath;
  }

  void _completeResult(FfmpegResult result) {
    if (!_resultCompleter.isCompleted) _resultCompleter.complete(result);
  }

  void _emitState(FfmpegTaskState state) {
    if (!_stateController.isClosed) _stateController.add(state);
  }
}
