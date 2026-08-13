import 'package:teigi/core/models/conversion_options.dart';
import 'package:teigi/core/models/media_file.dart';

/// 队列中单个任务的当前状态。
enum TaskStatus {
  queued, // 等待中
  running, // 正在转换
  paused, // 已暂停（等待中，不参与调度）
  completed, // 已完成
  failed, // 失败
  canceled; // 已取消
}

/// 队列中的一个转换任务。
class ConversionTask {
  final String id;
  final MediaFile source;

  /// 目标格式扩展名，如 'mp4'。null 表示尚未指定。
  String? targetFormat;

  ConversionOptions options;
  TaskStatus status;

  /// 当前进度 0.0 - 1.0。
  double progress;

  /// 预估剩余时间。
  Duration? remaining;

  /// 当前转换速度（ffmpeg speed=，如 2.5x）。
  double speedX;

  /// 输出文件路径（运行中/完成后有效）。
  String? outputPath;

  /// 失败原因。
  String? error;

  ConversionTask({
    required this.id,
    required this.source,
    this.targetFormat,
    this.options = const ConversionOptions(),
    this.status = TaskStatus.queued,
    this.progress = 0,
    this.remaining,
    this.speedX = 0,
    this.outputPath,
    this.error,
  });

  /// 此任务是否正在运行。
  bool get isRunning => status == TaskStatus.running;

  /// 此任务是否已完成/失败/取消（终态）。
  bool get isFinished =>
      status == TaskStatus.completed ||
      status == TaskStatus.failed ||
      status == TaskStatus.canceled;

  ConversionTask copyWith({
    String? targetFormat,
    ConversionOptions? options,
    TaskStatus? status,
    double? progress,
    Duration? remaining,
    double? speedX,
    String? outputPath,
    String? error,
  }) {
    return ConversionTask(
      id: id,
      source: source,
      targetFormat: targetFormat ?? this.targetFormat,
      options: options ?? this.options,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      remaining: remaining ?? this.remaining,
      speedX: speedX ?? this.speedX,
      outputPath: outputPath ?? this.outputPath,
      error: error ?? this.error,
    );
  }
}
