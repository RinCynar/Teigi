import 'dart:io';

import 'package:flutter/material.dart';
import 'package:teigi/core/domain/media_type.dart';
import 'package:teigi/core/models/conversion_task.dart';
import 'package:teigi/core/utils/file_identity.dart';
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

/// Media item surface with idle / hover / selected / running / error states.
class TeigiFileCard extends StatefulWidget {
  final ConversionTask task;
  final String conversionLabel;
  final String? metaLabel;
  final bool selected;
  final String configureLabel;
  final String removeLabel;
  final String retryLabel;
  final VoidCallback onConfigure;
  final VoidCallback onRemove;
  final VoidCallback? onRetry;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final GestureTapDownCallback? onSecondaryTapDown;

  const TeigiFileCard({
    super.key,
    required this.task,
    required this.conversionLabel,
    this.metaLabel,
    this.selected = false,
    required this.configureLabel,
    required this.removeLabel,
    required this.retryLabel,
    required this.onConfigure,
    required this.onRemove,
    this.onRetry,
    this.onTap,
    this.onDoubleTap,
    this.onSecondaryTapDown,
  });

  @override
  State<TeigiFileCard> createState() => _TeigiFileCardState();
}

class _TeigiFileCardState extends State<TeigiFileCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final task = widget.task;
    final type = task.source.mediaType;
    final failed = task.status == TaskStatus.failed;
    final completed = task.status == TaskStatus.completed;

    final Color fill;
    if (failed) {
      fill = scheme.errorContainer;
    } else if (widget.selected) {
      fill = scheme.primaryContainer;
    } else if (_hovered) {
      fill = scheme.surfaceContainerHigh;
    } else if (completed) {
      fill = scheme.surfaceContainerLowest;
    } else {
      fill = scheme.surfaceContainerLow;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onSecondaryTapDown: widget.onSecondaryTapDown,
        child: AnimatedContainer(
        duration: TeigiMotion.fast,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: TeigiRadii.fileItem,
          border: Border.all(
            color: widget.selected
                ? scheme.primary
                : task.isRunning
                    ? scheme.outlineVariant
                    : scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        padding: const EdgeInsets.all(TeigiSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MediaWell(task: task, type: type),
                const SizedBox(width: TeigiSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.source.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (widget.metaLabel != null) ...[
                        const SizedBox(height: TeigiSpacing.xxs),
                        Text(
                          widget.metaLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: widget.configureLabel,
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'configure') widget.onConfigure();
                    if (value == 'remove') widget.onRemove();
                    if (value == 'retry') widget.onRetry?.call();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'configure',
                      child: Text(widget.configureLabel),
                    ),
                    if (failed && widget.onRetry != null)
                      PopupMenuItem(
                        value: 'retry',
                        child: Text(widget.retryLabel),
                      ),
                    PopupMenuItem(
                      value: 'remove',
                      child: Text(widget.removeLabel),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: TeigiSpacing.md),
            Row(
              children: [
                Text(
                  widget.conversionLabel,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                if (completed)
                  Icon(Icons.check_circle, size: 18, color: scheme.primary),
                if (failed)
                  Icon(Icons.error_outline, size: 18, color: scheme.error),
              ],
            ),
            if (task.isRunning ||
                (task.progress > 0 && !completed && !failed)) ...[
              const SizedBox(height: TeigiSpacing.sm),
              ClipRRect(
                borderRadius: TeigiRadii.extraSmall,
                child: LinearProgressIndicator(
                  value: task.status == TaskStatus.queued ? null : task.progress,
                  minHeight: 4,
                ),
              ),
            ],
            if (failed && task.error != null) ...[
              const SizedBox(height: TeigiSpacing.xs),
              Text(
                task.error!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onErrorContainer),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}

class _MediaWell extends StatelessWidget {
  final ConversionTask task;
  final MediaType type;

  const _MediaWell({required this.task, required this.type});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ext = task.source.extension;

    Widget child;
    if (type == MediaType.image && FileIdentity.isReadableImage(ext)) {
      child = Image.file(
        File(task.source.path),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Icon(
          Icons.image_outlined,
          color: scheme.onSurfaceVariant,
        ),
      );
    } else {
      child = Icon(
        iconForMediaType(type),
        color: scheme.onSurfaceVariant,
      );
    }

    return ClipRRect(
      borderRadius: TeigiRadii.medium,
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: SizedBox(width: 72, height: 56, child: child),
      ),
    );
  }
}
