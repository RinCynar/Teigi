import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:teigi/core/ffmpeg/ffmpeg_runner.dart';
import 'package:teigi/core/models/conversion_task.dart';
import 'package:teigi/core/services/task_scheduler.dart';
import 'package:teigi/providers/ffmpeg_provider.dart';
import 'package:teigi/providers/queue_provider.dart';
import 'package:teigi/providers/settings_provider.dart';

/// 转换引擎：监听队列，调度 ffmpeg 进程，回写进度。
///
/// 手动启动模式：导入文件、设置格式后点击「开始转换」才会调度。
/// 并发数由设置决定；剩余时间基于滑动窗口平均速度估算。
class ConversionEngine {
  ConversionEngine({
    required this.ref,
    Logger? logger,
  }) : _logger = logger ?? Logger();

  final Ref ref;
  final Logger _logger;

  /// 运行中的任务 id -> 对应进程。
  final Map<String, Process> _running = {};
  final TaskScheduler _scheduler = const TaskScheduler();
  bool _disposed = false;
  bool _started = false;

  bool get isStarted => _started;

  void _setRunning(bool value) {
    _started = value;
    if (_disposed) return;
    ref.read(conversionRunningProvider.notifier).state = value;
  }

  /// 初始化：订阅队列变化（仅启动后才会调度新任务）。
  void init() {
    ref.listen<List<ConversionTask>>(queueProvider, (prev, next) {
      if (_started) _schedule();
    });
  }

  /// 开始处理队列。
  void start() {
    _setRunning(true);
    _schedule();
  }

  /// 停止处理：终止所有运行中的进程。
  void stop() {
    _setRunning(false);
    for (final process in _running.values) {
      try {
        process.kill(ProcessSignal.sigterm);
      } catch (_) {}
    }
    _running.clear();
  }

  void dispose() {
    _disposed = true;
    _started = false;
    for (final process in _running.values) {
      try {
        process.kill(ProcessSignal.sigterm);
      } catch (_) {}
    }
    _running.clear();
  }

  /// 从队列中取出可调度任务并启动。
  Future<void> _schedule() async {
    if (_disposed || !_started) return;

    final settings = ref.read(settingsProvider);
    final ffmpegStatus = ref.read(ffmpegStatusProvider);
    if (!ffmpegStatus.hasValue || !ffmpegStatus.value!.isAvailable) return;

    final capacity = settings.concurrency - _running.length;
    if (capacity <= 0) return;

    final picked = _scheduler.selectNext(
      tasks: ref.read(queueProvider),
      runningCount: _running.length,
      concurrency: settings.concurrency,
    );
    for (final task in picked) {
      if (task.targetFormat == null || task.targetFormat!.isEmpty) {
        continue;
      }
      unawaited(_runTask(task));
    }

    // 队列耗尽且无运行中任务时自动复位，避免按钮停留在「转换中…」。
    if (_running.isEmpty && _scheduler.isExhausted(ref.read(queueProvider))) {
      _setRunning(false);
    }
  }

  Future<void> _runTask(ConversionTask task) async {
    final settings = ref.read(settingsProvider);
    final ffmpegPath = ref.read(ffmpegStatusProvider).value!.info.path;
    final runner = FfmpegRunner(ffmpegPath: ffmpegPath);
    final notifier = ref.read(queueProvider.notifier);
    final speedSamples = _SpeedEstimator();

    // 硬件加速为全局设置：调度时统一应用到任务选项。
    final effectiveTask = task.copyWith(
      options: task.options.copyWith(hardwareAccel: settings.hardwareAccel),
    );

    notifier.updateTask(
      effectiveTask.copyWith(
        status: TaskStatus.running,
        startedAt: DateTime.now(),
      ),
    );

    try {
      final result = await runner.convert(
        effectiveTask,
        onProcessStart: (process) {
          _running[task.id] = process;
        },
        onProgress: (update) {
          if (_disposed) return;
          final current = notifier.taskById(task.id);
          if (current == null) return;
          final progress = update.progress ?? current.progress;
          notifier.updateTask(
            current.copyWith(
              progress: progress,
              speedX: update.speed ?? current.speedX,
              remaining: speedSamples.update(progress),
            ),
          );
        },
        onOutput: (outputPath) {
          if (_disposed) return;
          final current = notifier.taskById(task.id);
          if (current == null) return;
          notifier.updateTask(current.copyWith(outputPath: outputPath));
        },
      );

      if (result.isSuccess) {
        notifier.updateTask(
          effectiveTask.copyWith(
            status: TaskStatus.completed,
            progress: 1.0,
            outputPath: result.outputPath,
            completedAt: DateTime.now(),
          ),
        );
        _logger.i('转换完成: ${task.source.path} → ${result.outputPath}');
      } else {
        notifier.updateTask(
          effectiveTask.copyWith(
            status: TaskStatus.failed,
            error: result.error,
          ),
        );
        _logger.e('转换失败: ${task.source.path} (${result.error})');
      }
    } catch (e, stackTrace) {
      notifier.updateTask(
        effectiveTask.copyWith(status: TaskStatus.failed, error: e.toString()),
      );
      _logger.e('转换异常: ${task.source.path}', error: e, stackTrace: stackTrace);
    } finally {
      _running.remove(task.id);
      _schedule();
    }
  }
}

/// 基于滑动窗口的剩余时间估算器。
class _SpeedEstimator {
  final Queue<(Duration, double)> _samples = Queue();
  static const int _maxSamples = 10;
  static const Duration _maxWindow = Duration(seconds: 30);

  /// 传入最新进度，返回估算剩余时间；数据不足时返回 null。
  Duration? update(double progress) {
    final now = DateTime.now();
    final nowDuration = Duration(milliseconds: now.millisecondsSinceEpoch);
    _samples.add((nowDuration, progress));

    // 移除过期与多余的样本。
    while (_samples.length > _maxSamples) {
      _samples.removeFirst();
    }
    while (_samples.length > 2 &&
        nowDuration - _samples.first.$1 > _maxWindow) {
      _samples.removeFirst();
    }
    if (_samples.length < 2) return null;

    final first = _samples.first;
    final last = _samples.last;
    final progressDelta = last.$2 - first.$2;
    final timeDeltaMs = (last.$1 - first.$1).inMilliseconds;
    if (progressDelta <= 0.0001 || timeDeltaMs <= 0) return null;

    // 每秒进度。
    final ratePerSec = progressDelta / (timeDeltaMs / 1000);
    final remainingProgress = (1.0 - last.$2).clamp(0.0, 1.0);
    if (ratePerSec <= 0) return null;
    final remainingSec = remainingProgress / ratePerSec;
    return Duration(milliseconds: (remainingSec * 1000).round());
  }
}

/// True while the engine is processing the queue.
final conversionRunningProvider = StateProvider<bool>((ref) => false);

/// 转换引擎 Provider（保持单例运行）。
final conversionEngineProvider = Provider<ConversionEngine>((ref) {
  final engine = ConversionEngine(ref: ref);
  ref.onDispose(engine.dispose);
  engine.init();
  return engine;
});


