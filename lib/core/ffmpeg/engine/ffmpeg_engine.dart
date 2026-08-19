import 'package:teigi/core/ffmpeg/ffmpeg_command.dart';
import 'package:teigi/core/ffmpeg/progress_parser.dart';

/// Capabilities exposed by an FFmpeg engine implementation.
class FfmpegEngineCapabilities {
  final bool supportsCustomExecutablePath;
  final bool supportsHardwareAccelProbe;
  final bool supportsConcurrentSessions;

  const FfmpegEngineCapabilities({
    required this.supportsCustomExecutablePath,
    required this.supportsHardwareAccelProbe,
    required this.supportsConcurrentSessions,
  });
}

/// Where the currently selected FFmpeg executable came from.
enum FfmpegEngineSource { custom, bundled, systemPath }

/// Current availability of an FFmpeg engine.
class FfmpegEngineStatus {
  final bool isReady;
  final String? version;
  final String? resolvedExecutablePath;
  final FfmpegEngineSource? source;
  final FfmpegEngineSource? requestedSource;
  final String? requestedExecutablePath;
  final String? errorMessage;

  const FfmpegEngineStatus({
    required this.isReady,
    this.version,
    this.resolvedExecutablePath,
    this.source,
    this.requestedSource,
    this.requestedExecutablePath,
    this.errorMessage,
  });

  FfmpegEngineStatus withSource(FfmpegEngineSource value) {
    return FfmpegEngineStatus(
      isReady: isReady,
      version: version,
      resolvedExecutablePath: resolvedExecutablePath,
      source: value,
      requestedSource: requestedSource,
      requestedExecutablePath: requestedExecutablePath,
      errorMessage: errorMessage,
    );
  }

  FfmpegEngineStatus withRequestedCustomPath(String path) {
    return FfmpegEngineStatus(
      isReady: isReady,
      version: version,
      resolvedExecutablePath: resolvedExecutablePath,
      source: source,
      requestedSource: FfmpegEngineSource.custom,
      requestedExecutablePath: path,
      errorMessage: errorMessage,
    );
  }

  bool get isFallback =>
      requestedSource == FfmpegEngineSource.custom &&
      source != null &&
      source != FfmpegEngineSource.custom;

  static const unavailable = FfmpegEngineStatus(
    isReady: false,
    errorMessage: '未找到 ffmpeg，请在设置中指定可执行文件路径',
  );
}

/// Result of one FFmpeg process invocation.
///
/// This is the existing runner result model, moved next to the engine
/// contract so implementations and callers share one result type.
enum FfmpegTaskState { starting, running, completed, failed, cancelled }

class FfmpegResult {
  final int exitCode;
  final FfmpegTaskState state;
  final String? outputPath;
  final String? error;
  final String? stderr;

  const FfmpegResult({
    required this.exitCode,
    required this.state,
    this.outputPath,
    this.error,
    this.stderr,
  });

  bool get isSuccess => state == FfmpegTaskState.completed;

  bool get isCancelled => state == FfmpegTaskState.cancelled;
}

/// Abstraction over FFmpeg detection and process execution.
abstract class FfmpegEngine {
  FfmpegEngineCapabilities get capabilities;

  Future<FfmpegEngineStatus> detect({String? customExecutablePath});

  FfmpegTaskHandle run(FfmpegCommand command);
}

/// Handle for one running FFmpeg command.
abstract class FfmpegTaskHandle {
  Stream<ProgressUpdate> get progress;

  Stream<String> get outputPaths;

  Stream<FfmpegTaskState> get states;

  Future<void> cancel();

  Future<FfmpegResult> get result;
}
