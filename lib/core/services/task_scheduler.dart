import 'package:teigi/core/models/conversion_task.dart';

/// Picks the next queued tasks without starting processes.
///
/// [FfmpegRunner] executes a single task. This type only answers
/// "how many / which tasks may start now".
class TaskScheduler {
  const TaskScheduler();

  List<ConversionTask> selectNext({
    required List<ConversionTask> tasks,
    required int runningCount,
    required int concurrency,
  }) {
    final capacity = concurrency - runningCount;
    if (capacity <= 0) return const [];

    final selected = <ConversionTask>[];
    for (final task in tasks) {
      if (selected.length >= capacity) break;
      if (task.status != TaskStatus.queued) continue;
      if (task.targetFormat == null || task.targetFormat!.isEmpty) continue;
      selected.add(task);
    }
    return selected;
  }

  bool isExhausted(List<ConversionTask> tasks) {
    return tasks.every((t) => t.isFinished);
  }
}
