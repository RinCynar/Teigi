import 'dart:async';

import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new_full/level.dart';
import 'package:ffmpeg_kit_flutter_new_full/log.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import 'package:ffmpeg_kit_flutter_new_full/statistics.dart';
import 'package:teigi/core/ffmpeg/engine/ffmpeg_engine.dart';
import 'package:teigi/core/ffmpeg/ffmpeg_command.dart';
import 'package:teigi/core/ffmpeg/progress_parser.dart';

/// Mobile (Android/iOS) FFmpeg engine backed by the bundled ffmpeg-kit binary.
///
/// Unlike [DesktopFfmpegEngine], the mobile engine has no concept of a custom
/// executable path or a system PATH: it always uses the binary shipped inside
/// the package. Cancellation goes through ffmpeg-kit's session API instead of
/// process signals.
class MobileFfmpegEngine implements FfmpegEngine {
  @override
  FfmpegEngineCapabilities get capabilities => const FfmpegEngineCapabilities(
    supportsCustomExecutablePath: false,
    supportsHardwareAccelProbe: false,
    supportsConcurrentSessions: true,
  );

  @override
  Future<FfmpegEngineStatus> detect({String? customExecutablePath}) async {
    try {
      // ffmpeg-kit defaults to WARNING log level; raise it to INFO so later
      // sessions emit the `Duration:` line that ProgressParser needs to
      // compute fractional progress.
      await FFmpegKitConfig.setLogLevel(Level.avLogInfo);

      final version = await FFmpegKitConfig.getFFmpegVersion();
      if (version == null || version.isEmpty) {
        return const FfmpegEngineStatus(
          isReady: false,
          errorMessage: 'ffmpeg 不可用',
        );
      }
      return FfmpegEngineStatus(
        isReady: true,
        version: version,
        source: FfmpegEngineSource.bundled,
      );
    } catch (e) {
      return FfmpegEngineStatus(isReady: false, errorMessage: 'ffmpeg 不可用：$e');
    }
  }

  @override
  FfmpegTaskHandle run(FfmpegCommand command) {
    return _MobileFfmpegTaskHandle(command: command);
  }
}

class _MobileFfmpegTaskHandle implements FfmpegTaskHandle {
  _MobileFfmpegTaskHandle({required this.command}) {
    unawaited(_start());
  }

  final FfmpegCommand command;
  final StreamController<ProgressUpdate> _progressController =
      StreamController<ProgressUpdate>.broadcast();
  final StreamController<String> _outputController =
      StreamController<String>.broadcast();
  final StreamController<FfmpegTaskState> _stateController =
      StreamController<FfmpegTaskState>.broadcast();
  final Completer<FfmpegResult> _resultCompleter = Completer<FfmpegResult>();

  final ProgressParser _parser = ProgressParser();
  final StringBuffer _logs = StringBuffer();

  FFmpegSession? _session;
  bool _cancelRequested = false;

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
    final session = _session;
    if (session == null) return;
    await session.cancel();
  }

  Future<void> _start() async {
    _emitState(FfmpegTaskState.starting);
    _outputController.add(command.outputPath);

    try {
      final session = await FFmpegKit.executeWithArgumentsAsync(
        command.args,
        _onComplete,
        _onLog,
        _onStatistics,
      );
      _session = session;

      if (_cancelRequested) {
        await session.cancel();
      }
      _emitState(FfmpegTaskState.running);
    } catch (e) {
      _emitState(FfmpegTaskState.failed);
      _completeResult(
        FfmpegResult(
          exitCode: -1,
          state: FfmpegTaskState.failed,
          outputPath: command.outputPath,
          error: e.toString(),
        ),
      );
      await _closeControllers();
    }
  }

  void _onLog(Log log) {
    final message = log.getMessage();
    _logs.writeln(message);
    _parser.parseDurationLine(message);
  }

  void _onStatistics(Statistics statistics) {
    final elapsed = Duration(milliseconds: statistics.getTime());
    final speed = statistics.getSpeed();

    double? progress;
    final total = _parser.totalDuration;
    if (total != null && total.inMilliseconds > 0) {
      progress = (elapsed.inMilliseconds / total.inMilliseconds)
          .clamp(0.0, 1.0);
    }

    if (!_progressController.isClosed) {
      _progressController.add(
        ProgressUpdate(elapsed: elapsed, speed: speed, progress: progress),
      );
    }
  }

  Future<void> _onComplete(FFmpegSession session) async {
    final returnCode = await session.getReturnCode();

    if (_cancelRequested || ReturnCode.isCancel(returnCode)) {
      _emitState(FfmpegTaskState.cancelled);
      _completeResult(
        FfmpegResult(
          exitCode: returnCode?.getValue() ?? -1,
          state: FfmpegTaskState.cancelled,
          outputPath: command.outputPath,
          error: 'ffmpeg 已取消',
          stderr: _logs.toString(),
        ),
      );
    } else if (ReturnCode.isSuccess(returnCode)) {
      _emitState(FfmpegTaskState.completed);
      _completeResult(
        FfmpegResult(
          exitCode: 0,
          state: FfmpegTaskState.completed,
          outputPath: command.outputPath,
          stderr: _logs.toString(),
        ),
      );
    } else {
      _emitState(FfmpegTaskState.failed);
      _completeResult(
        FfmpegResult(
          exitCode: returnCode?.getValue() ?? -1,
          state: FfmpegTaskState.failed,
          outputPath: command.outputPath,
          error: 'ffmpeg 退出码 ${returnCode?.getValue() ?? '未知'}',
          stderr: _logs.toString(),
        ),
      );
    }

    await _closeControllers();
  }

  void _emitState(FfmpegTaskState state) {
    if (!_stateController.isClosed) _stateController.add(state);
  }

  void _completeResult(FfmpegResult result) {
    if (!_resultCompleter.isCompleted) _resultCompleter.complete(result);
  }

  Future<void> _closeControllers() async {
    await _progressController.close();
    await _outputController.close();
    await _stateController.close();
  }
}
