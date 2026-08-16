import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teigi/core/models/conversion_task.dart';
import 'package:teigi/core/models/format_preset.dart';
import 'package:teigi/core/models/media_file.dart';
import 'package:teigi/core/utils/file_identity.dart';
import 'package:teigi/features/convert/config_sheet.dart';
import 'package:teigi/features/convert/media_import.dart';
import 'package:teigi/features/format_config/format_selector.dart';
import 'package:teigi/i18n/strings.dart';
import 'package:teigi/providers/conversion_engine.dart';
import 'package:teigi/providers/ffmpeg_provider.dart';
import 'package:teigi/providers/queue_provider.dart';
import 'package:teigi/providers/recent_presets_provider.dart';
import 'package:teigi/shared/layout/content_constraint.dart';
import 'package:teigi/shared/widgets/teigi_file_card.dart';
import 'package:teigi/shared/widgets/teigi_mark.dart';
import 'package:teigi/theme/tokens.dart';
import 'package:teigi/widgets/ffmpeg_status_banner.dart';

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

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(queueProvider);
    final running = ref.watch(conversionRunningProvider);
    final width = MediaQuery.sizeOf(context).width;
    final size = TeigiBreakpoints.sizeOf(width);
    ref.watch(conversionEngineProvider);
    ref.watch(ffmpegStatusProvider);

    ConversionTask? configuring;
    if (_configuringId != null) {
      for (final t in tasks) {
        if (t.id == _configuringId) configuring = t;
      }
    }

    final workspace = ContentConstraint(
      padding: EdgeInsets.fromLTRB(
        size == TeigiWindowSize.compact ? TeigiSpacing.md : TeigiSpacing.page,
        TeigiSpacing.lg,
        size == TeigiWindowSize.compact ? TeigiSpacing.md : TeigiSpacing.page,
        TeigiSpacing.page,
      ),
      child: tasks.isEmpty
          ? _EmptyWorkspace(
              onAddFiles: () => _addFromPicker(),
              onPreset: _onEmptyPreset,
            )
          : _FilesWorkspace(
              tasks: tasks,
              running: running,
              configuringId: _configuringId,
              onAddFiles: () => _addFromPicker(),
              onConfigure: (task) => _openConfig(task, size),
              onStart: () => _start(),
            ),
    );

    return Stack(
      children: [
        workspace,
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
    );
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

  void _start() {
    final l10n = ref.read(l10nProvider);
    final missing = ref.read(queueProvider).where(
          (t) =>
              t.status == TaskStatus.queued &&
              (t.targetFormat == null || t.targetFormat!.isEmpty),
        ).length;
    ref.read(conversionEngineProvider).start();
    if (missing > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.missingFormatSkipped(missing))),
      );
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
                    l10n.dropToStart,
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
                    l10n.dropHint,
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
  final String? configuringId;
  final VoidCallback onAddFiles;
  final ValueChanged<ConversionTask> onConfigure;
  final VoidCallback onStart;

  const _FilesWorkspace({
    required this.tasks,
    required this.running,
    required this.configuringId,
    required this.onAddFiles,
    required this.onConfigure,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final recommended = tasks.where((t) => t.recommended).toList();
    final lead = recommended.isNotEmpty ? recommended.first : tasks.first;
    final outputExt = lead.targetFormat;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FfmpegStatusBanner(),
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
        ),
        const SizedBox(height: TeigiSpacing.xxs),
        Text(
          l10n.fileCount(tasks.length),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: TeigiSpacing.lg),
        if (recommended.isNotEmpty) ...[
          _Recommendation(
            task: lead,
            onUse: () {
              final preset = FormatPreset.byExtension(lead.targetFormat ?? '');
              if (preset != null) {
                ref.read(queueProvider.notifier).applyPreset(preset);
                ref.read(recentPresetsProvider.notifier).record(preset.id);
              }
            },
          ),
          const SizedBox(height: TeigiSpacing.lg),
        ],
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
                selected: task.id == configuringId,
                configureLabel: l10n.configure,
                removeLabel: l10n.remove,
                retryLabel: l10n.retry,
                onConfigure: () => onConfigure(task),
                onRemove: () =>
                    ref.read(queueProvider.notifier).removeTask(task.id),
                onRetry: task.status == TaskStatus.failed
                    ? () => ref.read(queueProvider.notifier).retryTask(task.id)
                    : null,
              );
            },
          ),
        ),
        const SizedBox(height: TeigiSpacing.lg),
        Text(l10n.output, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: TeigiSpacing.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: FormatSelector(
            value: outputExt,
            onChanged: (fmt) {
              if (fmt == null) return;
              final preset = FormatPreset.byExtension(fmt);
              if (preset != null) {
                ref.read(queueProvider.notifier).applyPreset(preset);
                ref.read(recentPresetsProvider.notifier).record(preset.id);
              } else {
                ref.read(queueProvider.notifier).setTargetFormatForAll(fmt);
              }
            },
          ),
        ),
        const SizedBox(height: TeigiSpacing.lg),
        Text(l10n.quality, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: TeigiSpacing.xs),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(
              value: QualityProfile.high.id,
              label: Text(l10n.qualityHigh),
            ),
            ButtonSegment(
              value: QualityProfile.standard.id,
              label: Text(l10n.qualityBalanced),
            ),
            ButtonSegment(
              value: QualityProfile.small.id,
              label: Text(l10n.qualitySmall),
            ),
          ],
          selected: {_qualityId(lead)},
          onSelectionChanged: (s) {
            final id = s.first;
            ref.read(queueProvider.notifier).applyQuality(
                  QualityProfile.all.firstWhere((q) => q.id == id),
                );
          },
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

  String _qualityId(ConversionTask task) {
    final crf = task.options.crf;
    for (final q in QualityProfile.all) {
      if (q.crf == crf) return q.id;
    }
    return QualityProfile.standard.id;
  }
}

class _Recommendation extends ConsumerWidget {
  final ConversionTask task;
  final VoidCallback onUse;

  const _Recommendation({required this.task, required this.onUse});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final scheme = Theme.of(context).colorScheme;
    final to = task.targetFormat ?? 'mp4';
    final preset = FormatPreset.byExtension(to);

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: TeigiRadii.large,
      child: Padding(
        padding: const EdgeInsets.all(TeigiSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.recommendedConversion,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: TeigiSpacing.xs),
                  Text(
                    l10n.conversionPair(task.source.extension, to),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (preset != null) ...[
                    const SizedBox(height: TeigiSpacing.xxs),
                    Text(
                      _presetSubtitle(preset),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: onUse,
              child: Text(l10n.useThis),
            ),
          ],
        ),
      ),
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
