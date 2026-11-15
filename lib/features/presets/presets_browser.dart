import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teigi/core/domain/media_type.dart';
import 'package:teigi/core/models/format_preset.dart';
import 'package:teigi/i18n/strings.dart';
import 'package:teigi/providers/quick_formats_provider.dart';
import 'package:teigi/providers/recent_presets_provider.dart';
import 'package:teigi/shared/widgets/teigi_mark.dart';
import 'package:teigi/theme/tokens.dart';

/// 预设与最近使用格式展示组件，供桌面端左栏与移动端抽屉共用。
class PresetsBrowser extends ConsumerWidget {
  final ValueChanged<FormatPreset> onSelectPreset;
  final bool scrollable;

  const PresetsBrowser({
    super.key,
    required this.onSelectPreset,
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final scheme = Theme.of(context).colorScheme;
    final recentIds = ref.watch(recentPresetsProvider);
    final pending = ref.watch(pendingPresetProvider);
    final quick = ref.watch(quickFormatsProvider);

    final recentPresets = <FormatPreset>[
      for (final id in recentIds)
        if (FormatPreset.byId(id) != null) FormatPreset.byId(id)!,
    ];

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. 最近使用分区 (Recent Presets)
        Row(
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 18,
              color: scheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              l10n.recentPresets,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
            ),
            if (pending != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      pending.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () =>
                          ref.read(pendingPresetProvider.notifier).state = null,
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Spacer(),
            if (recentIds.isNotEmpty)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: l10n.clearRecent,
                icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                onPressed: () =>
                    ref.read(recentPresetsProvider.notifier).clear(),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (recentPresets.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              l10n.noRecentPresets,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          )
        else
          TeigiPresetsGrid(
            children: [
              for (final preset in recentPresets)
                TeigiPresetCard(
                  title: preset.name,
                  subtitle: _presetSubtitle(preset),
                  selected: pending?.id == preset.id,
                  onTap: () => onSelectPreset(preset),
                ),
            ],
          ),

        const SizedBox(height: TeigiSpacing.xl),

        // 2. 全部预设分区 (All Presets)
        Row(
          children: [
            Icon(
              Icons.bookmark_outline_rounded,
              size: 18,
              color: scheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              l10n.allPresets,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 视频分类
        _CategoryGroup(
          title: l10n.video,
          presets: FormatPreset.builtins
              .where((p) => p.category == MediaType.video)
              .toList(),
          pendingId: pending?.id,
          onSelect: onSelectPreset,
        ),
        const SizedBox(height: TeigiSpacing.md),

        // 音频分类
        _CategoryGroup(
          title: l10n.audio,
          presets: FormatPreset.builtins
              .where((p) => p.category == MediaType.audio)
              .toList(),
          pendingId: pending?.id,
          onSelect: onSelectPreset,
        ),
        const SizedBox(height: TeigiSpacing.md),

        // 图像分类
        _CategoryGroup(
          title: l10n.image,
          presets: FormatPreset.builtins
              .where((p) => p.category == MediaType.image)
              .toList(),
          pendingId: pending?.id,
          onSelect: onSelectPreset,
        ),
        const SizedBox(height: TeigiSpacing.md),

        // 自定义预设
        Text(
          l10n.myPresets,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: TeigiSpacing.xs),
        if (quick.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
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
                  selected: pending?.extension.toLowerCase() ==
                      f.extension.toLowerCase(),
                  onPressed: () {
                    onSelectPreset(
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
    );

    if (scrollable) {
      return SingleChildScrollView(
        child: content,
      );
    }
    return content;
  }
}

class _CategoryGroup extends StatelessWidget {
  final String title;
  final List<FormatPreset> presets;
  final String? pendingId;
  final ValueChanged<FormatPreset> onSelect;

  const _CategoryGroup({
    required this.title,
    required this.presets,
    required this.pendingId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: TeigiSpacing.xs),
        TeigiPresetsGrid(
          children: [
            for (final preset in presets)
              TeigiPresetCard(
                title: preset.name,
                subtitle: _presetSubtitle(preset),
                selected: pendingId == preset.id,
                onTap: () => onSelect(preset),
              ),
          ],
        ),
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

