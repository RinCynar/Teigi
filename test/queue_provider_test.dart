import 'package:flutter_test/flutter_test.dart';

import 'package:teigi/core/models/conversion_task.dart';
import 'package:teigi/core/models/media_file.dart';
import 'package:teigi/providers/queue_provider.dart';

void main() {
  group('QueueNotifier', () {
    test('添加文件去重并追加', () {
      final notifier = QueueNotifier();
      final a = MediaFile(path: '/media/a.mp4');
      final b = MediaFile(path: '/media/b.mp4');

      notifier.addFiles([a, b, a]);
      expect(notifier.state.length, 2);
      expect(notifier.state[0].source, a);
      expect(notifier.state[1].source, b);
    });

    test('设置目标格式（全部与单个）', () {
      final notifier = QueueNotifier();
      final a = MediaFile(path: '/media/a.mp4');
      final b = MediaFile(path: '/media/b.mkv');
      notifier.addFiles([a, b]);

      notifier.setTargetFormatForAll('mp3');
      expect(notifier.state.every((t) => t.targetFormat == 'mp3'), isTrue);

      notifier.setTargetFormat(notifier.state[0].id, 'flac');
      expect(notifier.state[0].targetFormat, 'flac');
      expect(notifier.state[1].targetFormat, 'mp3');
    });

    test('移动与移除任务', () {
      final notifier = QueueNotifier();
      notifier.addFiles([
        MediaFile(path: '/media/a.mp4'),
        MediaFile(path: '/media/b.mp4'),
        MediaFile(path: '/media/c.mp4'),
      ]);

      final first = notifier.state[0];
      notifier.moveTask(first.id, 1);
      expect(notifier.state[0].id, isNot(first.id));

      final removed = notifier.state.last;
      notifier.removeTask(removed.id);
      expect(notifier.state.length, 2);
      expect(notifier.taskById(removed.id), isNull);
    });

    test('状态流转与可调度任务', () {
      final notifier = QueueNotifier();
      notifier.addFiles([
        MediaFile(path: '/media/a.mp4'),
        MediaFile(path: '/media/b.mp4'),
      ]);

      // 模拟引擎开始第一个任务。
      final first = notifier.nextSchedulable();
      expect(first, isNotNull);
      notifier.updateTask(first!.copyWith(status: TaskStatus.running));
      expect(notifier.nextSchedulable(), isNotNull);
      expect(notifier.state.where((t) => t.isRunning).length, 1);
    });

    test('清除已完成不影响运行中任务', () {
      final notifier = QueueNotifier();
      notifier.addFiles([
        MediaFile(path: '/media/a.mp4'),
        MediaFile(path: '/media/b.mp4'),
      ]);
      notifier.updateTask(notifier.state[0].copyWith(status: TaskStatus.running));
      notifier.updateTask(notifier.state[1].copyWith(status: TaskStatus.completed));
      notifier.clearCompleted();
      expect(notifier.state, hasLength(1));
      expect(notifier.state.single.status, TaskStatus.running);
    });
  });

  group('MediaFile', () {
    test('解析文件名与扩展名', () {
      final file = MediaFile(path: 'C:/media/My Video.mkv');
      expect(file.name, 'My Video.mkv');
      expect(file.baseName, 'My Video');
      expect(file.extension, 'mkv');
    });
  });
}
