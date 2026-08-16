import 'package:flutter/material.dart';
import 'package:teigi/core/domain/media_type.dart';
import 'package:teigi/core/models/conversion_task.dart';
import 'package:teigi/theme/tokens.dart';

IconData iconForMediaType(MediaType type) {
  return switch (type) {
    MediaType.video => Icons.movie_outlined,
    MediaType.audio => Icons.audiotrack_outlined,
    MediaType.image => Icons.image_outlined,
    MediaType.subtitle => Icons.subtitles_outlined,
    MediaType.document => Icons.description_outlined,
    MediaType.unknown => Icons.insert_drive_file_outlined,
  };
}

/// One conversion item as a Material surface.
class TeigiFileCard extends StatelessWidget {
  final ConversionTask task;
  final String conversionLabel;
  final String? recommendedLabel;
  final String configureLabel;
  final String removeLabel;
  final String retryLabel;
  final String Function(TaskStatus status) statusLabel;
  final VoidCallback onConfigure;
  final VoidCallback onRemove;
  final VoidCallback? onRetry;

  const TeigiFileCard({
    super.key,
    required this.task,
    required this.conversionLabel,
    this.recommendedLabel,
    required this.configureLabel,
    required this.removeLabel,
    required this.retryLabel,
    required this.statusLabel,
    required this.onConfigure,
    required this.onRemove,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final type = task.source.mediaType;

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: TeigiRadii.fileItem,
      child: Padding(
        padding: const EdgeInsets.all(TeigiSpacing.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: TeigiRadii.medium,
                  ),
                  child: Icon(iconForMediaType(type), color: scheme.primary),
                ),
                const SizedBox(width: TeigiSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.source.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: TeigiSpacing.xxs),
                      Text(
                        '${task.source.extension.toUpperCase()} · ${_typeName(type)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: removeLabel,
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'remove') onRemove();
                    if (value == 'retry') onRetry?.call();
                  },
                  itemBuilder: (context) => [
                    if (task.status == TaskStatus.failed && onRetry != null)
                      PopupMenuItem(value: 'retry', child: Text(retryLabel)),
                    PopupMenuItem(value: 'remove', child: Text(removeLabel)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: TeigiSpacing.sm),
            Row(
              children: [
                Text(
                  conversionLabel,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: scheme.onSurface,
                      ),
                ),
                if (task.recommended && recommendedLabel != null) ...[
                  const SizedBox(width: TeigiSpacing.xs),
                  Text(
                    recommendedLabel!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.primary,
                        ),
                  ),
                ],
              ],
            ),
            if (task.isRunning || task.progress > 0) ...[
              const SizedBox(height: TeigiSpacing.sm),
              ClipRRect(
                borderRadius: TeigiRadii.extraSmall,
                child: LinearProgressIndicator(
                  value: task.status == TaskStatus.queued ? null : task.progress,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: TeigiSpacing.xxs),
              Text(
                _progressLine(task),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
            if (task.status == TaskStatus.failed && task.error != null)
              Padding(
                padding: const EdgeInsets.only(top: TeigiSpacing.xs),
                child: Text(
                  task.error!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.error),
                ),
              ),
            const SizedBox(height: TeigiSpacing.sm),
            Row(
              children: [
                TextButton(
                  onPressed: onConfigure,
                  child: Text(configureLabel),
                ),
                const Spacer(),
                Text(
                  statusLabel(task.status),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: _statusColor(task.status, scheme),
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _typeName(MediaType type) => type.name;

  String _progressLine(ConversionTask task) {
    final pct = '${(task.progress * 100).toStringAsFixed(0)}%';
    final bits = <String>[pct];
    if (task.speedX > 0) {
      bits.add('${task.speedX.toStringAsFixed(1)}x');
    }
    if (task.remaining != null) {
      final d = task.remaining!;
      final m = d.inMinutes;
      final s = d.inSeconds.remainder(60);
      bits.add('ETA $m:${s.toString().padLeft(2, '0')}');
    }
    return bits.join(' · ');
  }

  Color _statusColor(TaskStatus status, ColorScheme scheme) {
    return switch (status) {
      TaskStatus.completed => scheme.primary,
      TaskStatus.failed => scheme.error,
      TaskStatus.running || TaskStatus.preparing => scheme.primary,
      _ => scheme.onSurfaceVariant,
    };
  }
}
