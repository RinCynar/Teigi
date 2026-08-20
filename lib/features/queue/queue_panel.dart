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
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              if (running)
                IconButton(
                  tooltip: l10n.stop,
                  onPressed: engine.stop,
                  icon: const Icon(Icons.stop_circle_outlined),
                ),
              TextButton(
                onPressed: () =>
                    ref.read(queueProvider.notifier).clearCompleted(),
                child: Text(l10n.clearCompleted),
              ),
            ],
          ),
          const SizedBox(height: TeigiSpacing.sm),
          Wrap(
            spacing: TeigiSpacing.xs,
            children: [
              ChoiceChip(
                label: Text(l10n.filterAll),
                selected: _filter == _QueueFilter.all,
                onSelected: (_) => setState(() => _filter = _QueueFilter.all),
              ),
              ChoiceChip(
                label: Text(l10n.filterActive),
                selected: _filter == _QueueFilter.active,
                onSelected: (_) =>
                    setState(() => _filter = _QueueFilter.active),
              ),
              ChoiceChip(
                label: Text(l10n.completed),
                selected: _filter == _QueueFilter.completed,
                onSelected: (_) =>
                    setState(() => _filter = _QueueFilter.completed),
              ),
              ChoiceChip(
                label: Text(l10n.failed),
                selected: _filter == _QueueFilter.failed,
                onSelected: (_) =>
                    setState(() => _filter = _QueueFilter.failed),
              ),
            ],
          ),
          const SizedBox(height: TeigiSpacing.md),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Text(
                      l10n.queueIdleHint,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                      ] else
                        for (final t in visible) _JobTile(task: t),
                    ],
                  ),
          ),
        ],
      ),
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
    return [
      Padding(
        padding: const EdgeInsets.only(
          top: TeigiSpacing.sm,
          bottom: TeigiSpacing.xs,
        ),
        child: Text(title, style: Theme.of(context).textTheme.labelLarge),
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

    return Material(
      color: scheme.surface,
      child: InkWell(
        onSecondaryTapDown: (d) => _menu(context, ref, d.globalPosition),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: TeigiSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      pair,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (task.status == TaskStatus.failed)
                    TextButton(
                      onPressed: () =>
                          ref.read(queueProvider.notifier).retryTask(task.id),
                      child: Text(l10n.retry),
                    ),
                  IconButton(
                    tooltip: l10n.menu,
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _menu(
                      context,
                      ref,
                      Offset(MediaQuery.sizeOf(context).width - 40, 80),
                    ),
                  ),
                ],
              ),
              if (task.isRunning) ...[
                const SizedBox(height: TeigiSpacing.xs),
                LinearProgressIndicator(
                  value: task.progress > 0 ? task.progress : null,
                  minHeight: 4,
                ),
                const SizedBox(height: 4),
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
              if (task.status == TaskStatus.failed && task.error != null)
                Text(
                  task.error!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: scheme.error),
                ),
              if (task.status == TaskStatus.completed)
                Text(
                  l10n.completed,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: scheme.primary),
                ),
            ],
          ),
        ),
      ),
    );
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
        ref.read(queueProvider.notifier).retryTask(task.id);
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
