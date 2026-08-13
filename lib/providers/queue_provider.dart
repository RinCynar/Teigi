import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teigi/core/models/conversion_options.dart';
import 'package:teigi/core/models/conversion_task.dart';
import 'package:teigi/core/models/media_file.dart';

/// 队列管理器：维护转换任务列表并控制其状态流转。
///
/// 转换执行由转换引擎（阶段 2）监听本 Provider 中的 queued 任务。
class QueueNotifier extends StateNotifier<List<ConversionTask>> {
  QueueNotifier() : super(const []);

  int _seq = 0;

  /// 追加文件到队列（去重：对队列中已有路径及输入列表内重复均生效）。
  void addFiles(List<MediaFile> files, {String? targetFormat}) {
    final existingPaths = state.map((t) => t.source.path).toSet();
    final newTasks = <ConversionTask>[];
    for (final f in files) {
      if (existingPaths.contains(f.path)) continue;
      existingPaths.add(f.path);
      newTasks.add(
        ConversionTask(
          id: 'task_${_seq++}_${DateTime.now().millisecondsSinceEpoch}',
          source: f,
          targetFormat: targetFormat,
        ),
      );
    }
    if (newTasks.isEmpty) return;
    state = [...state, ...newTasks];
  }

  /// 追加单个文件。
  void addFile(MediaFile file, {String? targetFormat}) =>
      addFiles([file], targetFormat: targetFormat);

  /// 移除指定任务。
  void removeTask(String id) {
    state = state.where((t) => t.id != id).toList();
  }

  /// 清空队列（移除已完成/失败/取消的任务；运行中的任务由引擎负责取消）。
  void clearAll() {
    state = state
        .where((t) => !t.isFinished)
        .map((t) => t.copyWith(status: TaskStatus.canceled))
        .toList();
  }

  /// 移除所有任务（无论状态）。
  void removeAll() => state = const [];

  /// 为目标格式批量设置。
  void setTargetFormatForAll(String? format) {
    state = [
      for (final t in state)
        t.copyWith(targetFormat: format),
    ];
  }

  /// 为单个任务设置目标格式。
  void setTargetFormat(String id, String? format) {
    state = [
      for (final t in state)
        if (t.id == id) t.copyWith(targetFormat: format) else t,
    ];
  }

  /// 为单个任务设置选项。
  void setOptions(String id, ConversionOptions options) {
    state = [
      for (final t in state) if (t.id == id) t.copyWith(options: options) else t,
    ];
  }

  /// 更新任务状态（供引擎回调）。
  void updateTask(ConversionTask updated) {
    state = [
      for (final t in state) if (t.id == updated.id) updated else t,
    ];
  }

  /// 移动任务在队列中的位置。
  void moveTask(String id, int delta) {
    final index = state.indexWhere((t) => t.id == id);
    if (index < 0) return;
    final target = index + delta;
    if (target < 0 || target >= state.length) return;
    final list = [...state];
    final task = list.removeAt(index);
    list.insert(target, task);
    state = list;
  }

  /// 获取任务。
  ConversionTask? taskById(String id) {
    for (final t in state) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// 获取下一个可调度的任务（queued 状态）。
  ConversionTask? nextSchedulable() {
    for (final t in state) {
      if (t.status == TaskStatus.queued) return t;
    }
    return null;
  }
}

/// 转换队列 Provider。
final queueProvider =
    StateNotifierProvider<QueueNotifier, List<ConversionTask>>((ref) {
  return QueueNotifier();
});
