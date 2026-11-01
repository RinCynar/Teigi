import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teigi/core/models/conversion_task.dart';
import 'package:teigi/core/services/platform_storage.dart';
import 'package:teigi/core/utils/open_path.dart';
import 'package:teigi/core/utils/platform_info.dart';
import 'package:teigi/i18n/strings.dart';
import 'package:teigi/providers/conversion_engine.dart';
import 'package:teigi/providers/queue_provider.dart';
import 'package:teigi/shared/layout/content_constraint.dart';
import 'package:teigi/theme/tokens.dart';

enum _QueueFilter { all, active, completed, failed }

/// Job manager: status and history. Not a second Convert workspace.
class QueuePanel extends ConsumerStatefulWidget {
  const QueuePanel({super.key});

  @override
  ConsumerState<QueuePanel> createState() => _QueuePanelState();
}

class _QueuePanelState extends ConsumerState<QueuePanel> {
  _QueueFilter _filter = _QueueFilter.all;

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final scheme = Theme.of(context).colorScheme;
    final tasks = ref.watch(queueProvider);
    final engine = ref.watch(conversionEngineProvider);
    final running = ref.watch(conversionRunningProvider);
    final visible = tasks.where(_matches).toList();

    return ContentConstraint(
      padding: const EdgeInsets.all(TeigiSpacing.page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.navQueue,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              if (running)
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: engine.stop,
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                  label: Text(l10n.stop),
                ),
              const SizedBox(width: TeigiSpacing.xs),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: scheme.borderSubtle, width: 1),
                ),
                onPressed: () =>
                    ref.read(queueProvider.notifier).clearCompleted(),
                child: Text(l10n.clearCompleted),
              ),
            ],
          ),
          const SizedBox(height: TeigiSpacing.md),
          Wrap(
            spacing: TeigiSpacing.xs,
            children: [
              _buildFilterChip(l10n.filterAll, _QueueFilter.all, scheme),
              _buildFilterChip(l10n.filterActive, _QueueFilter.active, scheme),
              _buildFilterChip(l10n.completed, _QueueFilter.completed, scheme),
              _buildFilterChip(l10n.failed, _QueueFilter.failed, scheme),
            ],
          ),
          const SizedBox(height: TeigiSpacing.md),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      padding: const EdgeInsets.all(TeigiSpacing.xxl),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: TeigiRadii.cardLarge,
                        border: Border.all(color: scheme.borderSubtle, width: 1.5),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 44,
                            color: scheme.primary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: TeigiSpacing.md),
                          Text(
                            l10n.queueIdleHint,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    children: [
                      if (_filter == _QueueFilter.all) ...[
                        ..._group(l10n.converting, visible, TaskStatus.running),
                        ..._group(l10n.queued, visible, TaskStatus.queued),
                        ..._group(
                          l10n.completed,
                          visible,
                          TaskStatus.completed,
                        ),
                        ..._group(l10n.failed, visible, TaskStatus.failed),
                        ..._group(l10n.canceled, visible, TaskStatus.canceled),
                      ] else
                        for (final t in visible) _JobTile(task: t),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, _QueueFilter filter, ColorScheme scheme) {
    final isSelected = _filter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: scheme.primary.withValues(alpha: 0.16),
      backgroundColor: scheme.surfaceContainerLow,
      side: BorderSide(
        color: isSelected ? scheme.primary : scheme.borderSubtle,
        width: isSelected ? 1.5 : 1.0,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      onSelected: (_) => setState(() => _filter = filter),
    );
  }

  bool _matches(ConversionTask t) {
    return switch (_filter) {
      _QueueFilter.all => true,
      _QueueFilter.active =>
        t.status == TaskStatus.running || t.status == TaskStatus.queued,
      _QueueFilter.completed => t.status == TaskStatus.completed,
      _QueueFilter.failed => t.status == TaskStatus.failed,
    };
  }

  List<Widget> _group(
    String title,
    List<ConversionTask> all,
    TaskStatus status,
  ) {
    final items = all.where((t) => t.status == status).toList();
    if (items.isEmpty) return const [];
    final scheme = Theme.of(context).colorScheme;
    return [
      Padding(
        padding: const EdgeInsets.only(
          top: TeigiSpacing.md,
          bottom: TeigiSpacing.xs,
        ),
        child: Row(
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
            ),
            const SizedBox(width: TeigiSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${items.length}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
              ),
            ),
          ],
        ),
      ),
      for (final t in items) _JobTile(task: t),
    ];
  }
}

class _JobTile extends ConsumerWidget {
  final ConversionTask task;

  const _JobTile({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final scheme = Theme.of(context).colorScheme;
    final pair = task.targetFormat == null
        ? task.source.name
        : '${task.source.name} → ${task.targetFormat!.toUpperCase()}';

    final Color statusColor;
    final IconData statusIcon;
    switch (task.status) {
      case TaskStatus.running:
        statusColor = scheme.primary;
        statusIcon = Icons.sync_rounded;
      case TaskStatus.completed:
        statusColor = scheme.primary;
        statusIcon = Icons.check_circle_rounded;
      case TaskStatus.failed:
        statusColor = scheme.error;
        statusIcon = Icons.error_outline_rounded;
      case TaskStatus.queued:
        statusColor = scheme.outlineVariant;
        statusIcon = Icons.schedule_rounded;
      case TaskStatus.canceled:
        statusColor = scheme.onSurfaceVariant.withValues(alpha: 0.5);
        statusIcon = Icons.cancel_outlined;
      default:
        statusColor = scheme.outlineVariant;
        statusIcon = Icons.help_outline_rounded;
    }

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: TeigiSpacing.sm),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: TeigiRadii.card,
            border: Border.all(
              color: task.isRunning
                  ? scheme.primary.withValues(alpha: 0.5)
                  : task.status == TaskStatus.failed
                      ? scheme.error.withValues(alpha: 0.5)
                      : scheme.borderSubtle,
              width: task.isRunning ? 1.5 : 1.0,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: TeigiRadii.card,
            child: InkWell(
              borderRadius: TeigiRadii.card,
              onSecondaryTapDown: (d) => _menu(context, ref, d.globalPosition),
              child: Padding(
                padding: const EdgeInsets.all(TeigiSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Icon(statusIcon, size: 18, color: statusColor),
                        ),
                        const SizedBox(width: TeigiSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pair,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              if (task.status == TaskStatus.failed && task.error != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  task.error!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: scheme.error,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (task.status == TaskStatus.failed)
                          TextButton(
                            onPressed: () => _retry(ref),
                            child: Text(l10n.retry),
                          ),
                        IconButton(
                          tooltip: l10n.menu,
                          icon: const Icon(Icons.more_vert_rounded),
                          onPressed: () => _menu(
                            context,
                            ref,
                            Offset(MediaQuery.sizeOf(context).width - 40, 80),
                          ),
                        ),
                      ],
                    ),
                    if (task.isRunning) ...[
                      const SizedBox(height: TeigiSpacing.sm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: task.progress > 0 ? task.progress : null,
                          minHeight: 4,
                          backgroundColor: scheme.surfaceContainerHighest,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        (task.progress > 0
                                ? '${(task.progress * 100).toStringAsFixed(0)}%'
                                : l10n.converting) +
                            (task.speedX > 0
                                ? ' · ${task.speedX.toStringAsFixed(1)}x'
                                : '') +
                            (task.remaining != null
                                ? ' · ETA ${l10n.formatDuration(task.remaining!)}'
                                : ''),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 重试失败任务；队列空闲（引擎已复位）时需显式重启调度。
  void _retry(WidgetRef ref) {
    ref.read(queueProvider.notifier).retryTask(task.id);
    final engine = ref.read(conversionEngineProvider);
    if (!engine.isStarted) engine.start();
  }

  Future<void> _menu(BuildContext context, WidgetRef ref, Offset global) async {
    final l10n = ref.read(l10nProvider);
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        global.dx,
        global.dy,
        global.dx,
        global.dy,
      ),
      items: [
        if (task.status == TaskStatus.failed)
          PopupMenuItem(value: 'retry', child: Text(l10n.retry)),
        PopupMenuItem(value: 'open', child: Text(l10n.openFile)),
        if (task.status == TaskStatus.completed && isMobile)
          PopupMenuItem(value: 'share', child: Text(l10n.shareFile)),
        if (!isMobile)
          PopupMenuItem(value: 'folder', child: Text(l10n.openFolder)),
        if (task.error != null || task.errorDetails != null)
          PopupMenuItem(value: 'log', child: Text(l10n.viewLog)),
        PopupMenuItem(value: 'remove', child: Text(l10n.remove)),
      ],
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case 'retry':
        _retry(ref);
      case 'open':
        await PlatformStorage.openFile(task.outputPath ?? task.source.path);
      case 'share':
        await PlatformStorage.shareFile(task.outputPath ?? task.source.path);
      case 'folder':
        await openParentFolder(task.outputPath ?? task.source.path);
      case 'log':
        final logText = task.errorDetails ?? task.error;
        if (logText != null) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l10n.viewLog),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: SelectableText(
                    logText,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: logText));
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.logCopied)),
                      );
                    }
                  },
                  child: Text(l10n.copyLog),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.ok),
                ),
              ],
            ),
          );
        }
      case 'remove':
        if (!task.isRunning) {
          ref.read(queueProvider.notifier).removeTask(task.id);
        }
    }
  }
}
