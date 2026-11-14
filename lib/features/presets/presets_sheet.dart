import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teigi/core/domain/media_type.dart';
import 'package:teigi/core/models/format_preset.dart';
import 'package:teigi/i18n/strings.dart';
import 'package:teigi/providers/queue_provider.dart';
import 'package:teigi/providers/quick_formats_provider.dart';
import 'package:teigi/providers/recent_presets_provider.dart';
import 'package:teigi/shared/widgets/teigi_mark.dart';
import 'package:teigi/theme/tokens.dart';

/// 预设选取与管理弹窗/底栏。
class PresetsSheet extends ConsumerWidget {
  final Set<String>? targetTaskIds;

  const PresetsSheet({super.key, this.targetTaskIds});

  static Future<void> show(BuildContext context, {Set<String>? targetTaskIds}) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 600) {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx, scrollController) => PresetsSheet(
            targetTaskIds: targetTaskIds,
          ),
        ),
      );
    } else {
      return showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 650),
            child: PresetsSheet(targetTaskIds: targetTaskIds),
          ),
        ),
      );
    }
  }

  void _apply(BuildContext context, WidgetRef ref, FormatPreset preset) {
    if (targetTaskIds != null && targetTaskIds!.isNotEmpty) {
      ref.read(queueProvider.notifier).applyPresetTo(targetTaskIds!, preset);
    } else {
      ref.read(queueProvider.notifier).applyPreset(preset);
    }
    ref.read(recentPresetsProvider.notifier).record(preset.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final quick = ref.watch(quickFormatsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(TeigiSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.bookmark_outline_rounded, color: scheme.primary),
              const SizedBox(width: TeigiSpacing.xs),
              Text(
                l10n.allPresets,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: TeigiSpacing.sm),
          Expanded(
            child: ListView(
              children: [
                Text(l10n.builtinPresets,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
                const SizedBox(height: TeigiSpacing.xs),
                _Group(
                  title: l10n.video,
                  presets: FormatPreset.builtins
                      .where((p) => p.category == MediaType.video)
                      .toList(),
                  onSelect: (p) => _apply(context, ref, p),
                ),
                const SizedBox(height: TeigiSpacing.md),
                _Group(
                  title: l10n.audio,
                  presets: FormatPreset.builtins
                      .where((p) => p.category == MediaType.audio)
                      .toList(),
                  onSelect: (p) => _apply(context, ref, p),
                ),
                const SizedBox(height: TeigiSpacing.md),
                _Group(
                  title: l10n.image,
                  presets: FormatPreset.builtins
                      .where((p) => p.category == MediaType.image)
                      .toList(),
                  onSelect: (p) => _apply(context, ref, p),
                ),
                const SizedBox(height: TeigiSpacing.lg),
                Text(l10n.myPresets,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
                const SizedBox(height: TeigiSpacing.xs),
                if (quick.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: TeigiSpacing.sm),
                    child: Text(
                      l10n.presetsEmpty,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
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
                            _apply(
                              context,
                              ref,
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
                          onDeleted: () => ref
                              .read(quickFormatsProvider.notifier)
                              .remove(f.extension),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final String title;
  final List<FormatPreset> presets;
  final ValueChanged<FormatPreset> onSelect;

  const _Group({
    required this.title,
    required this.presets,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
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
                onTap: () => onSelect(preset),
              ),
          ],
        ),
      ],
    );
  }
}
