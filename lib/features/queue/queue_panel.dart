import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teigi/core/models/conversion_task.dart';
import 'package:teigi/features/format_config/format_selector.dart';
import 'package:teigi/i18n/strings.dart';
import 'package:teigi/providers/conversion_engine.dart';
import 'package:teigi/providers/queue_provider.dart';
import 'package:teigi/widgets/queue_list.dart';

/// 队列面板：展示所有转换任务，支持选择目标格式与操作。
class QueuePanel extends ConsumerStatefulWidget {
  const QueuePanel({super.key});

  @override
  ConsumerState<QueuePanel> createState() => _QueuePanelState();
}

class _QueuePanelState extends ConsumerState<QueuePanel> {
  /// 编辑模式：首次点击「编辑队列」取消运行中任务并标记为可操作，
  /// 再次点击「清空队列」才会真正移除全部任务。
  bool _editMode = false;

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final tasks = ref.watch(queueProvider);
    final engine = ref.watch(conversionEngineProvider);
    final engineRunning = ref.watch(conversionRunningProvider);

    if (tasks.isEmpty) {
      // 队列空时退出编辑模式。
      if (_editMode) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _editMode = false);
        });
      }
      return _EmptyQueue(l10n: l10n);
    }

    final running = tasks.where((t) => t.isRunning).length;
    final queued = tasks.where((t) => t.status == TaskStatus.queued).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(
                l10n.queueCount(tasks.length),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (running > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    l10n.runningCount(running, queued),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.auto_fix_high_outlined),
                tooltip: l10n.setFormatForAll,
                onPressed: () => _setFormatForAll(context, ref),
              ),
              if (engineRunning)
                IconButton(
                  icon: const Icon(Icons.stop_circle_outlined),
                  tooltip: l10n.stop,
                  onPressed: () => engine.stop(),
                ),
              FilledButton.icon(
                onPressed: engineRunning ? null : () => _startAll(context, ref),
                icon: const Icon(Icons.play_arrow),
                label: Text(engineRunning ? l10n.converting : l10n.start),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: _editMode ? _clearAll : _enterEditMode,
                icon: Icon(_editMode ? Icons.delete_sweep_outlined : Icons.edit_outlined),
                label: Text(_editMode ? l10n.clearQueue : l10n.editQueue),
              ),
            ],
          ),
        ),
        Expanded(child: QueueList(tasks: tasks)),
      ],
    );
  }

  /// 进入编辑模式：停止转换并将未完成任务标记为取消。
  void _enterEditMode() {
    ref.read(conversionEngineProvider).stop();
    ref.read(queueProvider.notifier).clearAll();
    setState(() => _editMode = true);
  }

  /// 清空全部任务并退出编辑模式。
  void _clearAll() {
    ref.read(queueProvider.notifier).removeAll();
    setState(() => _editMode = false);
  }

  /// 一键为全部任务设置目标格式。
  Future<void> _setFormatForAll(BuildContext context, WidgetRef ref) async {
    final l10n = ref.read(l10nProvider);
    String? selected;
    final format = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.setFormatForAll),
          content: FormatSelector(
            value: selected,
            onChanged: (v) => setState(() => selected = v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(selected),
              child: Text(l10n.ok),
            ),
          ],
        ),
      ),
    );
    if (format != null) {
      ref.read(queueProvider.notifier).setTargetFormatForAll(format);
    }
  }

  void _startAll(BuildContext context, WidgetRef ref) {
    final l10n = ref.read(l10nProvider);
    final tasks = ref.read(queueProvider);
    final missingFormat = tasks.where(
      (t) =>
          t.status == TaskStatus.queued &&
          (t.targetFormat == null || t.targetFormat!.isEmpty),
    ).length;

    ref.read(conversionEngineProvider).start();

    if (missingFormat > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.missingFormatSkipped(missingFormat))),
      );
    }
  }
}

/// 空队列占位视图。
class _EmptyQueue extends StatelessWidget {
  final L10n l10n;

  const _EmptyQueue({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_library_outlined, size: 72, color: scheme.outline),
          const SizedBox(height: 16),
          Text(
            l10n.queueEmpty,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.queueEmptyHint,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
