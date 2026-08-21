import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teigi/core/models/conversion_task.dart';
import 'package:teigi/core/models/format_preset.dart';
import 'package:teigi/core/models/media_file.dart';
import 'package:teigi/core/utils/file_identity.dart';
import 'package:teigi/core/utils/open_path.dart';
import 'package:teigi/core/utils/platform_info.dart';
import 'package:teigi/features/convert/batch_config_sheet.dart';
import 'package:teigi/features/convert/config_sheet.dart';
import 'package:teigi/features/convert/media_import.dart';
import 'package:teigi/features/format_config/format_picker.dart';
import 'package:teigi/i18n/strings.dart';
import 'package:teigi/providers/conversion_engine.dart';
import 'package:teigi/providers/ffmpeg_provider.dart';
import 'package:teigi/providers/queue_provider.dart';
import 'package:teigi/providers/recent_presets_provider.dart';
import 'package:teigi/providers/selection_provider.dart';
import 'package:teigi/shared/layout/content_constraint.dart';
import 'package:teigi/shared/widgets/teigi_file_card.dart';
import 'package:teigi/shared/widgets/teigi_mark.dart';
import 'package:teigi/theme/tokens.dart';
import 'package:teigi/shared/widgets/ffmpeg_status_banner.dart';

/// Single-column conversion workspace. Queue is not this page.
class ConvertPage extends ConsumerStatefulWidget {
  const ConvertPage({super.key});

  static const _import = MediaImport();

  @override
  ConsumerState<ConvertPage> createState() => _ConvertPageState();

  static void addFiles(WidgetRef ref, List<MediaFile> files) {
    if (files.isEmpty) return;
    final pending = ref.read(pendingPresetProvider);
    ref.read(queueProvider.notifier).addFiles(files, preset: pending);
    if (pending != null) {
      ref.read(pendingPresetProvider.notifier).state = null;
    }
  }
}

class _ConvertPageState extends ConsumerState<ConvertPage> {
  String? _configuringId;
  String? _anchorId;

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(queueProvider);
    final workspace = [
      for (final t in tasks)
        if (t.status == TaskStatus.queued) t,
    ];
    final running = ref.watch(conversionRunningProvider);
    final selected = ref.watch(selectionProvider);
    final width = MediaQuery.sizeOf(context).width;
    final size = TeigiBreakpoints.sizeOf(width);
    ref.watch(ffmpegStatusProvider);

    ConversionTask? configuring;
    if (_configuringId != null) {
      for (final t in workspace) {
        if (t.id == _configuringId) configuring = t;
      }
    }

    final page = RepaintBoundary(
      child: ContentConstraint(
        padding: EdgeInsets.fromLTRB(
          size == TeigiWindowSize.compact ? TeigiSpacing.md : TeigiSpacing.page,
          TeigiSpacing.lg,
          size == TeigiWindowSize.compact ? TeigiSpacing.md : TeigiSpacing.page,
          TeigiSpacing.page,
        ),
      child: workspace.isEmpty
          ? _EmptyWorkspace(
              onAddFiles: () => _addFromPicker(),
              onPreset: _onEmptyPreset,
            )
          : _FilesWorkspace(
              tasks: workspace,
              running: running,
              selected: selected,
              configuringId: _configuringId,
              onAddFiles: () => _addFromPicker(),
              onConfigure: (task) => _openConfig(task, size),
              onStart: () => _start(workspace),
              onClick: (task, ctrl, shift) => _click(task, workspace, ctrl, shift),
              onContext: (task, pos) => _contextMenu(task, pos, size),
            ),
      ),
    );

    return PopScope(
      canPop: selected.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          ref.read(selectionProvider.notifier).clear();
          setState(() => _configuringId = null);
        }
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyA, control: true): () {
            ref.read(selectionProvider.notifier).selectAll(workspace.map((t) => t.id));
          },
          const SingleActivator(LogicalKeyboardKey.escape): () {
            ref.read(selectionProvider.notifier).clear();
            setState(() => _configuringId = null);
          },
          const SingleActivator(LogicalKeyboardKey.delete): () {
            ref.read(queueProvider.notifier).removeTasks(ref.read(selectionProvider));
            ref.read(selectionProvider.notifier).clear();
          },
          const SingleActivator(LogicalKeyboardKey.enter): () {
            final ids = ref.read(selectionProvider);
            if (ids.length == 1) {
              ConversionTask? task;
              for (final t in workspace) {
                if (t.id == ids.first) task = t;
              }
              if (task != null) _openConfig(task, size);
            } else if (ids.length > 1) {
              BatchConfigSheet.open(context, ids: ids);
            }
          },
        },
        child: Focus(
          autofocus: true,
          child: Stack(
            children: [
              page,
              if (configuring != null && size == TeigiWindowSize.expanded)
                Positioned(
                  top: 0,
                  right: 0,
                  bottom: 0,
                  width: TeigiBreakpoints.configSheet,
                  child: Material(
                    elevation: 1,
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    child: ConvertConfigSheet(
                      task: configuring,
                      onClose: () => setState(() => _configuringId = null),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _click(
    ConversionTask task,
    List<ConversionTask> workspace,
    bool ctrl,
    bool shift,
  ) {
    final ids = workspace.map((t) => t.id).toList();
    ref.read(selectionProvider.notifier).handleClick(
          task.id,
          orderedIds: ids,
          ctrl: ctrl,
          shift: shift,
          anchorId: _anchorId,
        );
    if (!shift) _anchorId = task.id;
  }

  Future<void> _contextMenu(
    ConversionTask task,
    Offset global,
    TeigiWindowSize size,
  ) async {
    final selected = ref.read(selectionProvider);
    if (!selected.contains(task.id)) {
      ref.read(selectionProvider.notifier).selectOnly(task.id);
    }
    final l10n = ref.read(l10nProvider);
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(global.dx, global.dy, global.dx, global.dy),
      items: [
        PopupMenuItem(value: 'configure', child: Text(l10n.configure)),
        PopupMenuItem(value: 'format', child: Text(l10n.targetFormat)),
        PopupMenuItem(value: 'open', child: Text(l10n.openFile)),
        PopupMenuItem(value: 'folder', child: Text(l10n.openFolder)),
        PopupMenuItem(value: 'remove', child: Text(l10n.remove)),
      ],
    );
    if (!mounted || action == null) return;
    final ids = ref.read(selectionProvider);
    switch (action) {
      case 'configure':
        if (ids.length > 1) {
          await BatchConfigSheet.open(context, ids: ids);
        } else {
          await _openConfig(task, size);
        }
      case 'format':
        final fmt = await FormatPicker.show(context, current: task.targetFormat, size: size);
        if (fmt != null) {
          ref.read(queueProvider.notifier).setTargetFormatFor(ids, fmt);
        }
      case 'open':
        await openLocalPath(task.source.path);
      case 'folder':
        await openParentFolder(task.source.path);
      case 'remove':
        ref.read(queueProvider.notifier).removeTasks(ids);
        ref.read(selectionProvider.notifier).clear();
    }
  }

  Future<void> _addFromPicker() async {
    final files = await ConvertPage._import.pickFiles();
    if (!mounted) return;
    ConvertPage.addFiles(ref, files);
  }

  void _onEmptyPreset(FormatPreset preset) {
    ref.read(pendingPresetProvider.notifier).state = preset;
    ref.read(recentPresetsProvider.notifier).record(preset.id);
    final l10n = ref.read(l10nProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.presetWillApply(preset.name))),
    );
  }

  Future<void> _openConfig(ConversionTask task, TeigiWindowSize size) async {
    if (size == TeigiWindowSize.expanded) {
      setState(() => _configuringId = task.id);
      return;
    }
    await ConvertConfigSheet.open(context, task: task, asOverlay: false);
  }

  Future<void> _start(List<ConversionTask> workspace) async {
    final l10n = ref.read(l10nProvider);
    final missing = workspace
        .where((t) => t.targetFormat == null || t.targetFormat!.isEmpty)
        .length;
    if (missing == 0) {
      ref.read(conversionEngineProvider).start();
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.startConversion),
        content: Text(l10n.missingOutput(missing)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'review'),
            child: Text(l10n.reviewMissing),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'ready'),
            child: Text(l10n.startReady),
          ),
        ],
      ),
    );
    if (choice == 'ready') {
      ref.read(conversionEngineProvider).start();
    }
  }
}

class _EmptyWorkspace extends ConsumerWidget {
  final VoidCallback onAddFiles;
  final ValueChanged<FormatPreset> onPreset;

  const _EmptyWorkspace({required this.onAddFiles, required this.onPreset});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final scheme = Theme.of(context).colorScheme;
    final pending = ref.watch(pendingPresetProvider);
    final recentIds = ref.watch(recentPresetsProvider);
    final recent = [
      for (final id in recentIds)
        if (FormatPreset.byId(id) != null) FormatPreset.byId(id)!,
    ];
    final cards = recent.isEmpty
        ? [
            FormatPreset.byId('video_mp4')!,
            FormatPreset.byId('audio_mp3')!,
            FormatPreset.byId('video_webm')!,
            FormatPreset.byId('audio_flac')!,
          ]
        : recent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FfmpegStatusBanner(),
        Text(
          l10n.appTitle,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.convertSubtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: TeigiSpacing.sm),
                  Text(
                    isMobile ? l10n.selectToStart : l10n.dropToStart,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: TeigiSpacing.xl),
                  FilledButton.icon(
                    onPressed: onAddFiles,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.addFiles),
                  ),
                  const SizedBox(height: TeigiSpacing.md),
                  Text(
                    isMobile ? l10n.mobileImportHint : l10n.dropHint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Text(l10n.recentPresets, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: TeigiSpacing.sm),
        Wrap(
          spacing: TeigiSpacing.sm,
          runSpacing: TeigiSpacing.sm,
          children: [
            for (final preset in cards)
              TeigiPresetCard(
                title: preset.name,
                subtitle: _presetSubtitle(preset),
                selected: pending?.id == preset.id,
                onTap: () => onPreset(preset),
              ),
          ],
        ),
      ],
    );
  }
}

class _FilesWorkspace extends ConsumerWidget {
  final List<ConversionTask> tasks;
  final bool running;
  final Set<String> selected;
  final String? configuringId;
  final VoidCallback onAddFiles;
  final ValueChanged<ConversionTask> onConfigure;
  final VoidCallback onStart;
  final void Function(ConversionTask task, bool ctrl, bool shift) onClick;
  final void Function(ConversionTask task, Offset global) onContext;

  const _FilesWorkspace({
    required this.tasks,
    required this.running,
    required this.selected,
    required this.configuringId,
    required this.onAddFiles,
    required this.onConfigure,
    required this.onStart,
    required this.onClick,
    required this.onContext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final ready = tasks.where((t) => t.targetFormat?.isNotEmpty == true).length;
    final missing = tasks.length - ready;
    final size = TeigiBreakpoints.sizeOf(MediaQuery.sizeOf(context).width);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FfmpegStatusBanner(),
        if (selected.isEmpty)
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.convertTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              TextButton.icon(
                onPressed: onAddFiles,
                icon: const Icon(Icons.add),
                label: Text(l10n.addFiles),
              ),
            ],
          )
        else
          _SelectionBar(selected: selected, size: size),
        const SizedBox(height: TeigiSpacing.xxs),
        Text(
          l10n.readySummary(tasks.length, ready, missing),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: TeigiSpacing.lg),
        Expanded(
          child: ListView.separated(
            itemCount: tasks.length,
            separatorBuilder: (_, _) => const SizedBox(height: TeigiSpacing.sm),
            itemBuilder: (context, index) {
              final task = tasks[index];
              return TeigiFileCard(
                task: task,
                conversionLabel: task.targetFormat == null
                    ? l10n.noTargetFormat
                    : l10n.conversionPair(
                        task.source.extension,
                        task.targetFormat!,
                      ),
                metaLabel: _metaFor(task),
                selected: selected.contains(task.id) || task.id == configuringId,
                configureLabel: l10n.configure,
                removeLabel: l10n.remove,
                retryLabel: l10n.retry,
                onConfigure: () => onConfigure(task),
                onRemove: () =>
                    ref.read(queueProvider.notifier).removeTask(task.id),
                onTap: () {
                  final keys = HardwareKeyboard.instance.logicalKeysPressed;
                  onClick(
                    task,
                    keys.contains(LogicalKeyboardKey.controlLeft) ||
                        keys.contains(LogicalKeyboardKey.controlRight),
                    keys.contains(LogicalKeyboardKey.shiftLeft) ||
                        keys.contains(LogicalKeyboardKey.shiftRight),
                  );
                },
                onDoubleTap: () => onConfigure(task),
                onSecondaryTapDown: (d) => onContext(task, d.globalPosition),
              );
            },
          ),
        ),
        const SizedBox(height: TeigiSpacing.xl),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: running ? null : onStart,
            child: Text(running ? l10n.converting : l10n.startConversion),
          ),
        ),
      ],
    );
  }
}

class _SelectionBar extends ConsumerWidget {
  final Set<String> selected;
  final TeigiWindowSize size;

  const _SelectionBar({required this.selected, required this.size});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final compact = size == TeigiWindowSize.compact;
    final actions = <Widget>[
      TextButton(
        onPressed: () => ref.read(selectionProvider.notifier).clear(),
        child: Text(l10n.deselect),
      ),
      TextButton(
        onPressed: () {
          final ids = ref
              .read(queueProvider)
              .where((t) => t.status == TaskStatus.queued)
              .map((t) => t.id);
          ref.read(selectionProvider.notifier).selectAll(ids);
        },
        child: Text(l10n.selectAll),
      ),
      TextButton(
        onPressed: () async {
          final fmt = await FormatPicker.show(
            context,
            current: null,
            size: size,
          );
          if (fmt != null) {
            ref.read(queueProvider.notifier).setTargetFormatFor(selected, fmt);
          }
        },
        child: Text(l10n.targetFormat),
      ),
      TextButton(
        onPressed: () => BatchConfigSheet.open(context, ids: selected),
        child: Text(l10n.configure),
      ),
      TextButton(
        onPressed: () {
          ref.read(queueProvider.notifier).removeTasks(selected);
          ref.read(selectionProvider.notifier).clear();
        },
        child: Text(l10n.remove),
      ),
    ];

    if (compact) {
      // 手机断点：标题一行、操作按钮换行，避免窄屏溢出。
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.selectedCount(selected.length),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: TeigiSpacing.xs),
          Wrap(spacing: TeigiSpacing.xs, children: actions),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.selectedCount(selected.length),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ...actions,
      ],
    );
  }
}

String _presetSubtitle(FormatPreset preset) {
  if (preset.videoCodec != null) {
    return _codecLabel(preset.videoCodec!);
  }
  if (preset.audioCodec != null) {
    if (preset.extension == 'mp3') return '192 kbps';
    return _codecLabel(preset.audioCodec!);
  }
  return preset.container.toUpperCase();
}

String _codecLabel(String codec) {
  return switch (codec) {
    'libx264' => 'H.264',
    'libx265' => 'H.265',
    'libvpx-vp9' => 'VP9',
    'libmp3lame' => 'MP3',
    'libopus' => 'Opus',
    'libvorbis' => 'Vorbis',
    'pcm_s16le' => 'PCM',
    'libwebp' => 'WebP',
    'mjpeg' => 'JPEG',
    _ => codec,
  };
}

String _metaFor(ConversionTask task) {
  final parts = <String>[
    ?FileIdentity.sizeLabel(task.source.path),
    task.source.extension.toUpperCase(),
  ];
  return parts.join(' · ');
}
