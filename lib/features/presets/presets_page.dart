import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teigi/core/domain/media_type.dart';
import 'package:teigi/core/models/format_preset.dart';
import 'package:teigi/i18n/strings.dart';
import 'package:teigi/providers/queue_provider.dart';
import 'package:teigi/providers/quick_formats_provider.dart';
import 'package:teigi/providers/recent_presets_provider.dart';
import 'package:teigi/shared/layout/content_constraint.dart';
import 'package:teigi/shared/widgets/teigi_mark.dart';
import 'package:teigi/theme/tokens.dart';

class PresetsPage extends ConsumerWidget {
  const PresetsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final quick = ref.watch(quickFormatsProvider);

    return ContentConstraint(
      padding: const EdgeInsets.all(TeigiSpacing.page),
      child: ListView(
        children: [
          Text(l10n.navPresets, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: TeigiSpacing.xl),
          Text(l10n.builtinPresets, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: TeigiSpacing.sm),
          _PresetGroup(
            title: l10n.video,
            presets: FormatPreset.builtins
                .where((p) => p.category == MediaType.video)
                .toList(),
          ),
          const SizedBox(height: TeigiSpacing.md),
          _PresetGroup(
            title: l10n.audio,
            presets: FormatPreset.builtins
                .where((p) => p.category == MediaType.audio)
                .toList(),
          ),
          const SizedBox(height: TeigiSpacing.md),
          _PresetGroup(
            title: l10n.image,
            presets: FormatPreset.builtins
                .where((p) => p.category == MediaType.image)
                .toList(),
          ),
          const SizedBox(height: TeigiSpacing.xl),
          Text(l10n.myPresets, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: TeigiSpacing.sm),
          if (quick.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.presetsEmpty,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: TeigiSpacing.sm),
                FilledButton.tonal(
                  onPressed: () => context.go('/convert'),
                  child: Text(l10n.createPreset),
                ),
              ],
            )
          else
            Wrap(
              spacing: TeigiSpacing.xs,
              runSpacing: TeigiSpacing.xs,
              children: [
                for (final f in quick)
                  InputChip(
                    label: Text(f.extension.toUpperCase()),
                    onPressed: () {
                      ref.read(queueProvider.notifier).applyPreset(
                            FormatPreset(
                              id: 'quick_${f.extension}',
                              name: f.extension.toUpperCase(),
                              category: MediaType.unknown,
                              container: f.extension,
                              extension: f.extension,
                              options: f.options,
                              isBuiltIn: false,
                            ),
                          );
                    },
                    onDeleted: () =>
                        ref.read(quickFormatsProvider.notifier).remove(f.extension),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PresetGroup extends ConsumerWidget {
  final String title;
  final List<FormatPreset> presets;

  const _PresetGroup({required this.title, required this.presets});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: TeigiSpacing.xs),
        Wrap(
          spacing: TeigiSpacing.xs,
          runSpacing: TeigiSpacing.xs,
          children: [
            for (final preset in presets)
              TeigiPresetCard(
                title: preset.name,
                subtitle: preset.videoCodec ?? preset.audioCodec ?? preset.container,
                onTap: () {
                  ref.read(queueProvider.notifier).applyPreset(preset);
                  ref.read(recentPresetsProvider.notifier).record(preset.id);
                },
              ),
          ],
        ),
      ],
    );
  }
}
