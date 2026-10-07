import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:teigi/core/domain/conversion_error.dart';
import 'package:teigi/core/ffmpeg/engine/ffmpeg_engine.dart';
import 'package:teigi/core/ffmpeg/ffmpeg_command.dart';
import 'package:teigi/core/ffmpeg/ffmpeg_command_builder.dart';
import 'package:teigi/core/ffmpeg/progress_parser.dart';
import 'package:teigi/core/models/conversion_task.dart';
import 'package:teigi/core/services/foreground_service.dart';
import 'package:teigi/core/services/platform_storage.dart';
import 'package:teigi/core/services/task_scheduler.dart';
import 'package:teigi/core/utils/memory_trimmer.dart';
import 'package:teigi/core/utils/platform_info.dart';
import 'package:teigi/providers/ffmpeg_provider.dart';
import 'package:teigi/providers/queue_provider.dart';
import 'package:teigi/providers/settings_provider.dart';

/// 转换引擎：监听队列，调度 ffmpeg 进程，回写进度。
///
/// 手动启动模式：导入文件、设置格式后点击「开始转换」才会调度。
/// 并发数由设置决定；剩余时间基于滑动窗口平均速度估算。
class ConversionEngine {
  ConversionEngine({required this.ref, Logger? logger})
    : _logger = logger ?? Logger();

  final Ref ref;
  final Logger _logger;

  /// 运行中的任务 id -> 对应引擎任务句柄。
  final Map<String, FfmpegTaskHandle> _running = {};

  /// 已被 [_runTask] 领取、尚未注册进 [_running] 的任务。
  /// 登记是同步的：调度器据此跳过这些任务，避免 await 窗口期内重复启动。
  final Set<String> _starting = {};
  final TaskScheduler _scheduler = const TaskScheduler();
  StreamSubscription<ForegroundAction>? _foregroundSubscription;
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
    // Android 前台服务通知的「取消」按钮 → 取消所有运行中的任务。
    _foregroundSubscription = ForegroundService.actions.listen((action) {
      if (action == ForegroundAction.cancel) _cancelAll();
    });
  }

  /// 取消所有运行中的任务。
  void _cancelAll() {
    for (final task in _running.values) {
      unawaited(task.cancel());
    }
  }

  /// 开始处理队列。
  void start() {
    _setRunning(true);
    // Android 13+ 需要通知权限才能展示前台服务通知。
    unawaited(ForegroundService.ensureNotificationPermission());
    _schedule();
  }

  /// 停止处理：终止所有运行中的进程。
  void stop() {
    _setRunning(false);
    for (final task in _running.values) {
      unawaited(task.cancel());
    }
    _running.clear();
  }

  void dispose() {
    _disposed = true;
    _started = false;
    _foregroundSubscription?.cancel();
    _foregroundSubscription = null;
    for (final task in _running.values) {
      unawaited(task.cancel());
    }
    _running.clear();
  }

  /// 从队列中取出可调度任务并启动。
  Future<void> _schedule() async {
    if (_disposed || !_started) return;

    final settings = ref.read(settingsProvider);
    final ffmpegStatus = ref.read(ffmpegStatusProvider);
    if (!ffmpegStatus.hasValue || !ffmpegStatus.value!.isReady) return;

    final runningCount = _running.length + _starting.length;
    final capacity = settings.concurrency - runningCount;
    if (capacity <= 0) return;

    final picked = _scheduler.selectNext(
      tasks: ref.read(queueProvider),
      runningCount: runningCount,
      concurrency: settings.concurrency,
    );
    for (final task in picked) {
      if (task.targetFormat == null || task.targetFormat!.isEmpty) {
        continue;
      }
      if (_starting.contains(task.id) || _running.containsKey(task.id)) {
        continue;
      }
      unawaited(_runTask(task));
    }

    // 队列耗尽且无运行中任务时自动复位，避免按钮停留在「转换中…」。
    // Android：同时停止前台服务，释放通知栏。
    if (_running.isEmpty &&
        _starting.isEmpty &&
        _scheduler.isExhausted(ref.read(queueProvider))) {
      _setRunning(false);
      unawaited(ForegroundService.stop());
      MemoryTrimmer.trimIdleMemory(delay: const Duration(milliseconds: 500));
    }
  }

  Future<void> _runTask(ConversionTask task) async {
    // 同步登记，确保 await 窗口期内重入的 _schedule 不会再次领取该任务。
    _starting.add(task.id);
    final settings = ref.read(settingsProvider);
    final engine = ref.read(ffmpegEngineProvider);
    final notifier = ref.read(queueProvider.notifier);

    // 输出目录：若未指定且为 Android，自动使用公共存储 Download/Teigi
    var outDir = task.options.outputDirectory;
    if ((outDir == null || outDir.isEmpty) && isAndroid) {
      outDir = await PlatformStorage.getDefaultOutputDirectory();
    }
    // await 期间可能已被 stop()/dispose()：放弃启动，任务保持 queued 等待下次调度。
    if (_disposed || !_started) {
      _starting.remove(task.id);
      return;
    }

    // 硬件加速为全局设置：调度时统一应用到任务选项。
    final effectiveTask = task.copyWith(
      options: task.options.copyWith(
        outputDirectory: outDir,
        hardwareAccel: settings.hardwareAccel,
      ),
    );

    const builder = FfmpegCommandBuilder();
    final command = builder.build(effectiveTask);
    // 桌面端硬件编码器依赖 GPU 厂商驱动，失败时回退软件编码重试一次；
    // 命令未因硬件加速发生变化（如格式无对应硬编）时无需重试。
    final fallbackCommand =
        effectiveTask.options.hardwareAccel && !isAndroid
        ? builder.build(
            effectiveTask.copyWith(
              options: effectiveTask.options.copyWith(hardwareAccel: false),
            ),
            outputPath: command.outputPath,
          )
        : null;

    notifier.updateTask(
      effectiveTask.copyWith(
        status: TaskStatus.running,
        outputPath: command.outputPath,
        startedAt: DateTime.now(),
      ),
    );

    // Android：启动前台服务，常驻通知显示文件名与取消按钮。
    unawaited(ForegroundService.start(fileName: task.source.name));
    var speedSamples = _SpeedEstimator();
    try {
      var result = await _execute(engine, notifier, task, command, speedSamples);

      if (fallbackCommand != null &&
          !_sameArgs(fallbackCommand.args, command.args) &&
          !result.isSuccess &&
          !result.isCancelled) {
        _logger.w('硬件加速失败，回退软件编码重试: ${task.source.path}');
        speedSamples = _SpeedEstimator();
        final retried = notifier.taskById(task.id);
        if (retried != null) {
          notifier.updateTask(
            retried.copyWith(status: TaskStatus.running, progress: 0),
          );
        }
        result = await _execute(
          engine,
          notifier,
          task,
          fallbackCommand,
          speedSamples,
        );
      }

      final current = notifier.taskById(task.id) ?? effectiveTask;

      if (result.isSuccess) {
        notifier.updateTask(
          current.copyWith(
            status: TaskStatus.completed,
            progress: 1.0,
            outputPath: result.outputPath,
            completedAt: DateTime.now(),
          ),
        );
        if (result.outputPath != null) {
          unawaited(PlatformStorage.scanMediaFile(result.outputPath!));
        }
        _logger.i('转换完成: ${task.source.path} → ${result.outputPath}');
      } else if (result.isCancelled) {
        notifier.updateTask(
          current.copyWith(
            status: TaskStatus.canceled,
            error: result.error,
            errorDetails: result.stderr,
          ),
        );
        _logger.i('转换取消: ${task.source.path}');
      } else {
        final conversionError = ConversionError.fromFfmpeg(
          exitCode: result.exitCode,
          cancelled: result.isCancelled,
          error: result.error,
          stderr: result.stderr,
        );
        notifier.updateTask(
          current.copyWith(
            status: TaskStatus.failed,
            error: conversionError.message,
            errorDetails: conversionError.details,
          ),
        );
        _logger.e(
          '转换失败: ${task.source.path} (${conversionError.kind}) '
          '${conversionError.details ?? ''}',
        );
      }
    } catch (e, stackTrace) {
      final conversionError = ConversionError.unknown(e);
      final current = notifier.taskById(task.id) ?? effectiveTask;
      notifier.updateTask(
        current.copyWith(
          status: TaskStatus.failed,
          error: conversionError.message,
          errorDetails: conversionError.details,
        ),
      );
      _logger.e('转换异常: ${task.source.path}', error: e, stackTrace: stackTrace);
    } finally {
      _starting.remove(task.id);
      _schedule();
    }
  }

  /// 运行单个命令：注册句柄、订阅进度/状态流并等待结果。
  Future<FfmpegResult> _execute(
    FfmpegEngine engine,
    QueueNotifier notifier,
    ConversionTask task,
    FfmpegCommand command,
    _SpeedEstimator speedSamples,
  ) async {
    final handle = engine.run(command);
    _running[task.id] = handle;
    StreamSubscription<ProgressUpdate>? progressSubscription;
    StreamSubscription<String>? outputSubscription;
    StreamSubscription<FfmpegTaskState>? stateSubscription;
    try {
      progressSubscription = handle.progress.listen((update) {
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
        final percent = (progress * 100).round();
        unawaited(
          ForegroundService.updateProgress(
            progress > 0
                ? '${task.source.name} $percent%'
                : '${task.source.name} 转换中',
          ),
        );
      });
      outputSubscription = handle.outputPaths.listen((outputPath) {
        if (_disposed) return;
        final current = notifier.taskById(task.id);
        if (current == null) return;
        // 命令构造时已知的输出路径优先；stderr 解析只作为兜底。
        if (current.outputPath != null) return;
        notifier.updateTask(current.copyWith(outputPath: outputPath));
      });
      stateSubscription = handle.states.listen((state) {
        if (_disposed) return;
        final current = notifier.taskById(task.id);
        if (current == null) return;
        switch (state) {
          case FfmpegTaskState.running:
            if (current.status != TaskStatus.running) {
              notifier.updateTask(current.copyWith(status: TaskStatus.running));
            }
            break;
          case FfmpegTaskState.cancelled:
            notifier.updateTask(current.copyWith(status: TaskStatus.canceled));
            break;
          case FfmpegTaskState.starting:
          case FfmpegTaskState.completed:
          case FfmpegTaskState.failed:
            break;
        }
      });

      return await handle.result;
    } finally {
      await progressSubscription?.cancel();
      await outputSubscription?.cancel();
      await stateSubscription?.cancel();
      _running.remove(task.id);
    }
  }

  static bool _sameArgs(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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
