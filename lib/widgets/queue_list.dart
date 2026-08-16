import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teigi/core/models/conversion_task.dart';
import 'package:teigi/features/format_config/format_selector.dart';
import 'package:teigi/features/format_config/options_editor.dart';
import 'package:teigi/i18n/strings.dart';
import 'package:teigi/providers/queue_provider.dart';

/// 队列任务列表：桌面表格风格展示任务及操作。
class QueueList extends ConsumerWidget {
  final List<ConversionTask> tasks;

  const QueueList({super.key, required this.tasks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 表头。
          _TableHeader(l10n: l10n),
          const Divider(height: 1),
          // 行列表。
          Expanded(
            child: ListView.separated(
              itemCount: tasks.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
              itemBuilder: (context, index) => _TaskRow(task: tasks[index]),
            ),
          ),
        ],
      ),
    );
  }
}

/// 表格表头。
class _TableHeader extends StatelessWidget {
  final L10n l10n;

  const _TableHeader({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(color: scheme.onSurfaceVariant);

    return Container(
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('文件', style: labelStyle)),
          SizedBox(width: 132, child: Text('目标格式', style: labelStyle)),
          SizedBox(width: 76, child: Text('状态', style: labelStyle)),
          Expanded(flex: 2, child: Text('进度', style: labelStyle)),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

/// 单个任务行（桌面风格，带悬停高亮）。
class _TaskRow extends ConsumerStatefulWidget {
  final ConversionTask task;

  const _TaskRow({required this.task});

  @override
  ConsumerState<_TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends ConsumerState<_TaskRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final scheme = Theme.of(context).colorScheme;
    final task = widget.task;

    final subtitle = task.targetFormat == null
        ? l10n.noTargetFormat
        : '${task.source.extension} → ${task.targetFormat}';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: _hovered ? scheme.surfaceContainerHigh : scheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // 文件名 + 详情。
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.source.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  if (task.status == TaskStatus.failed && task.error != null)
                    Text(
                      task.error!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.error),
                    ),
                ],
              ),
            ),
            // 目标格式。
            SizedBox(
              width: 132,
              child: FormatSelector(
                value: task.targetFormat,
                onChanged: (fmt) => ref
                    .read(queueProvider.notifier)
                    .setTargetFormat(task.id, fmt),
                onQuickOptionsApplied: (options) =>
                    ref.read(queueProvider.notifier).setOptions(task.id, options),
              ),
            ),
            // 状态。
            SizedBox(
              width: 76,
              child: Row(
                children: [
                  _statusIcon(task.status, scheme),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _statusLabel(task.status, l10n),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            // 进度。
            Expanded(
              flex: 2,
              child: task.isRunning
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: task.progress,
                            minHeight: 5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${(task.progress * 100).toStringAsFixed(1)}%'
                          '${task.remaining != null ? '  ${l10n.remainingLabel} ${l10n.formatDuration(task.remaining!)}' : ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    )
                  : Text(
                      task.status == TaskStatus.completed
                          ? '100%'
                          : (task.status == TaskStatus.failed
                              ? l10n.failed
                              : '—'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
            ),
            const SizedBox(width: 8),
            // 操作菜单。
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              tooltip: l10n.configOptions,
              onSelected: (action) => _handleAction(context, action),
              itemBuilder: (context) => [
                PopupMenuItem(value: 'up', child: Text(l10n.moveUp)),
                PopupMenuItem(value: 'down', child: Text(l10n.moveDown)),
                PopupMenuItem(value: 'options', child: Text(l10n.configOptions)),
                PopupMenuItem(value: 'remove', child: Text(l10n.remove)),
              ],
            ),
          ],
        ),
      ),
    );
  }


  void _handleAction(BuildContext context, String action) {
    final notifier = ref.read(queueProvider.notifier);
    switch (action) {
      case 'up':
        notifier.moveTask(widget.task.id, -1);
      case 'down':
        notifier.moveTask(widget.task.id, 1);
      case 'remove':
        notifier.removeTask(widget.task.id);
      case 'options':
        showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (_) => OptionsEditor(task: widget.task),
        );
    }
  }

  Icon _statusIcon(TaskStatus status, ColorScheme scheme) {
    final (icon, color) = switch (status) {
      TaskStatus.queued => (Icons.schedule, scheme.onSurfaceVariant),
      TaskStatus.preparing => (Icons.hourglass_top, scheme.primary),
      TaskStatus.running => (Icons.downloading, scheme.primary),
      TaskStatus.paused => (Icons.pause_circle_outline, scheme.onSurfaceVariant),
      TaskStatus.completed => (Icons.check_circle, scheme.primary),
      TaskStatus.failed => (Icons.error, scheme.error),
      TaskStatus.canceled => (Icons.cancel, scheme.outline),
    };
    return Icon(icon, color: color, size: 18);
  }

  String _statusLabel(TaskStatus status, L10n l10n) => switch (status) {
        TaskStatus.queued => l10n.queued,
        TaskStatus.preparing => l10n.converting,
        TaskStatus.running => l10n.converting,
        TaskStatus.paused => l10n.stop,
        TaskStatus.completed => l10n.completed,
        TaskStatus.failed => l10n.failed,
        TaskStatus.canceled => l10n.canceled,
      };
}

