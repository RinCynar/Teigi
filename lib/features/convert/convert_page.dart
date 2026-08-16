import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teigi/core/models/conversion_options.dart';
import 'package:teigi/core/models/conversion_task.dart';
import 'package:teigi/core/models/format_preset.dart';
import 'package:teigi/core/models/media_file.dart';
import 'package:teigi/features/convert/media_import.dart';
import 'package:teigi/features/format_config/format_selector.dart';
import 'package:teigi/features/format_config/options_editor.dart';
import 'package:teigi/i18n/strings.dart';
import 'package:teigi/providers/conversion_engine.dart';
import 'package:teigi/providers/ffmpeg_provider.dart';
import 'package:teigi/providers/queue_provider.dart';
import 'package:teigi/providers/recent_presets_provider.dart';
import 'package:teigi/shared/layout/content_constraint.dart';
import 'package:teigi/shared/widgets/teigi_drop_zone.dart';
import 'package:teigi/shared/widgets/teigi_file_card.dart';
import 'package:teigi/theme/tokens.dart';
import 'package:teigi/widgets/ffmpeg_status_banner.dart';

/// Home workspace: drop → choose → convert.
class ConvertPage extends ConsumerWidget {
  const ConvertPage({super.key});

  static const _import = MediaImport();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final tasks = ref.watch(queueProvider);
    final running = ref.watch(conversionRunningProvider);
    ref.watch(conversionEngineProvider);
    ref.watch(ffmpegStatusProvider);

    return Column(
      children: [
        const FfmpegStatusBanner(),
        Expanded(
          child: ContentConstraint(
            padding: const EdgeInsets.fromLTRB(
              TeigiSpacing.page,
              TeigiSpacing.md,
              TeigiSpacing.page,
              TeigiSpacing.page,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.appTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: TeigiSpacing.xxs),
                Text(
                  l10n.convertSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: TeigiSpacing.xl),
                if (tasks.isEmpty)
                  Expanded(
                    child: TeigiDropZone(
                      highlighted: false,
                      onAddFiles: () => _addFromPicker(context, ref),
                      onAddFolder: () => _addFromFolder(context, ref),
                      title: l10n.dropFiles,
                      actionLabel: l10n.addFiles,
                      folderLabel: l10n.importFolder,
                      formatsLabel: l10n.supportedFormats,
                    ),
                  )
                else ...[
                  _RecentRow(onPicked: (preset) {
                    ref.read(queueProvider.notifier).applyPreset(preset);
                    ref.read(recentPresetsProvider.notifier).record(preset.id);
                  }),
                  const SizedBox(height: TeigiSpacing.md),
                  Text(
                    l10n.filesHeading,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: TeigiSpacing.sm),
                  Expanded(
                    child: ListView.separated(
                      itemCount: tasks.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: TeigiSpacing.sm),
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
                          recommendedLabel: l10n.recommended,
                          configureLabel: l10n.configure,
                          removeLabel: l10n.remove,
                          retryLabel: l10n.retry,
                          statusLabel: (s) => _statusLabel(s, l10n),
                          onConfigure: () => _configure(context, ref, task),
                          onRemove: () =>
                              ref.read(queueProvider.notifier).removeTask(task.id),
                          onRetry: task.status == TaskStatus.failed
                              ? () => ref
                                  .read(queueProvider.notifier)
                                  .retryTask(task.id)
                              : null,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: TeigiSpacing.md),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: running
                          ? null
                          : () => _start(context, ref),
                      icon: Icon(running ? Icons.hourglass_top : Icons.play_arrow),
                      label: Text(
                        running ? l10n.converting : l10n.startConversion,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  static Future<void> addFiles(
    BuildContext context,
    WidgetRef ref,
    List<MediaFile> files,
  ) async {
    if (files.isEmpty) return;
    ref.read(queueProvider.notifier).addFiles(files);
    final l10n = ref.read(l10nProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.filesAdded(files.length))),
      );
    }
  }

  static Future<void> _addFromPicker(BuildContext context, WidgetRef ref) async {
    final files = await _import.pickFiles();
    if (!context.mounted) return;
    await addFiles(context, ref, files);
  }

  static Future<void> _addFromFolder(BuildContext context, WidgetRef ref) async {
    final l10n = ref.read(l10nProvider);
    final files = await _import.pickFolder(dialogTitle: l10n.chooseFolder);
    if (!context.mounted) return;
    await addFiles(context, ref, files);
  }

  static void _start(BuildContext context, WidgetRef ref) {
    final l10n = ref.read(l10nProvider);
    final missing = ref.read(queueProvider).where(
          (t) =>
              t.status == TaskStatus.queued &&
              (t.targetFormat == null || t.targetFormat!.isEmpty),
        ).length;
    ref.read(conversionEngineProvider).start();
    if (missing > 0 && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.missingFormatSkipped(missing))),
      );
    }
  }

  static Future<void> _configure(
    BuildContext context,
    WidgetRef ref,
    ConversionTask task,
  ) async {
    final l10n = ref.read(l10nProvider);
    String? selected = task.targetFormat;
    ConversionOptions options = task.options;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.configure),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FormatSelector(
                    value: selected,
                    onChanged: (v) => setState(() => selected = v),
                    onQuickOptionsApplied: (o) => setState(() => options = o),
                  ),
                  if (selected != null) ...[
                    const SizedBox(height: TeigiSpacing.sm),
                    OptionsForm(
                      targetFormat: selected,
                      initial: options,
                      onChanged: (o) => options = o,
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final notifier = ref.read(queueProvider.notifier);
                notifier.setTargetFormat(task.id, selected);
                notifier.setOptions(task.id, options);
                Navigator.of(dialogContext).pop();
              },
              child: Text(l10n.apply),
            ),
          ],
        ),
      ),
    );
  }

  static String _statusLabel(TaskStatus status, L10n l10n) => switch (status) {
        TaskStatus.queued => l10n.queued,
        TaskStatus.preparing => l10n.converting,
        TaskStatus.running => l10n.converting,
        TaskStatus.paused => l10n.stop,
        TaskStatus.completed => l10n.completed,
        TaskStatus.failed => l10n.failed,
        TaskStatus.canceled => l10n.canceled,
      };
}

class _RecentRow extends ConsumerWidget {
  final ValueChanged<FormatPreset> onPicked;

  const _RecentRow({required this.onPicked});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final recentIds = ref.watch(recentPresetsProvider);
    final recent = [
      for (final id in recentIds)
        if (FormatPreset.byId(id) != null) FormatPreset.byId(id)!,
    ];
    final chips = recent.isEmpty
        ? FormatPreset.builtins.take(6).toList()
        : recent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.recentPresets, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: TeigiSpacing.xs),
        Wrap(
          spacing: TeigiSpacing.xs,
          runSpacing: TeigiSpacing.xs,
          children: [
            for (final preset in chips)
              ActionChip(
                label: Text(preset.name),
                onPressed: () => onPicked(preset),
              ),
          ],
        ),
      ],
    );
  }
}
