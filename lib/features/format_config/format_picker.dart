import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teigi/core/domain/media_type.dart';
import 'package:teigi/core/models/format_copy.dart';
import 'package:teigi/core/models/format_preset.dart';
import 'package:teigi/i18n/strings.dart';
import 'package:teigi/providers/recent_presets_provider.dart';
import 'package:teigi/theme/tokens.dart';

/// Desktop format picker. Replaces a grouped DropdownButton.
class FormatPicker {
  static Future<String?> show(
    BuildContext context, {
    required String? current,
    required TeigiWindowSize size,
  }) {
    if (size == TeigiWindowSize.compact) {
      return Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text(L10nScope.of(context))),
            body: FormatPickerBody(
              current: current,
              onPicked: (ext) => Navigator.of(context).pop(ext),
            ),
          ),
        ),
      );
    }
    return showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        child: SizedBox(
          width: 560,
          height: 520,
          child: FormatPickerBody(
            current: current,
            onPicked: (ext) => Navigator.of(ctx).pop(ext),
          ),
        ),
      ),
    );
  }
}

/// Avoid needing l10n in the route title before the widget tree has a Consumer.
class L10nScope {
  static String of(BuildContext context) => 'Format';
}

class FormatPickerBody extends ConsumerStatefulWidget {
  final String? current;
  final ValueChanged<String> onPicked;

  const FormatPickerBody({
    super.key,
    required this.current,
    required this.onPicked,
  });

  @override
  ConsumerState<FormatPickerBody> createState() => _FormatPickerBodyState();
}

class _FormatPickerBodyState extends ConsumerState<FormatPickerBody> {
  final _query = TextEditingController();
  final _custom = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    _custom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final q = _query.text;
    final recentIds = ref.watch(recentPresetsProvider);
    final recent = [
      for (final id in recentIds)
        if (FormatPreset.byId(id) != null) FormatPreset.byId(id)!,
    ];

    final video = _filter(FormatPreset.builtins, MediaType.video, q);
    final audio = _filter(FormatPreset.builtins, MediaType.audio, q);
    final image = _filter(FormatPreset.builtins, MediaType.image, q);

    return Padding(
      padding: const EdgeInsets.all(TeigiSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.chooseFormat, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: TeigiSpacing.sm),
          TextField(
            controller: _query,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.searchFormats,
              prefixIcon: const Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: TeigiSpacing.md),
          Expanded(
            child: ListView(
              children: [
                if (recent.isNotEmpty && q.isEmpty) ...[
                  _section(context, l10n.recentPresets),
                  _grid([
                    for (final p in recent) FormatCopy.of(p.extension),
                  ]),
                  const SizedBox(height: TeigiSpacing.md),
                ],
                if (video.isNotEmpty) ...[
                  _section(context, l10n.video),
                  _grid(video),
                  const SizedBox(height: TeigiSpacing.md),
                ],
                if (audio.isNotEmpty) ...[
                  _section(context, l10n.audio),
                  _grid(audio),
                  const SizedBox(height: TeigiSpacing.md),
                ],
                if (image.isNotEmpty) ...[
                  _section(context, l10n.image),
                  _grid(image),
                  const SizedBox(height: TeigiSpacing.md),
                ],
                _section(context, l10n.other),
                Text(l10n.customExtension, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: TeigiSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _custom,
                        decoration: InputDecoration(
                          hintText: l10n.customFormatHint,
                          prefixText: '.',
                          isDense: true,
                        ),
                        onSubmitted: _submitCustom,
                      ),
                    ),
                    const SizedBox(width: TeigiSpacing.sm),
                    FilledButton(
                      onPressed: () => _submitCustom(_custom.text),
                      child: Text(l10n.ok),
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

  List<FormatCopy> _filter(
    List<FormatPreset> all,
    MediaType type,
    String query,
  ) {
    return [
      for (final p in all)
        if (p.category == type)
          FormatCopy.of(p.extension),
    ].where((c) => c.matches(query)).toList();
  }

  Widget _section(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TeigiSpacing.xs),
      child: Text(title, style: Theme.of(context).textTheme.labelLarge),
    );
  }

  Widget _grid(List<FormatCopy> items) {
    return Wrap(
      spacing: TeigiSpacing.sm,
      runSpacing: TeigiSpacing.sm,
      children: [
        for (final item in items)
          _FormatTile(
            copy: item,
            selected: widget.current?.toLowerCase() == item.title.toLowerCase(),
            onTap: () {
              final ext = item.title.toLowerCase();
              final preset = FormatPreset.byExtension(ext);
              if (preset != null) {
                ref.read(recentPresetsProvider.notifier).record(preset.id);
              }
              widget.onPicked(ext == 'jpeg' ? 'jpg' : ext);
            },
          ),
      ],
    );
  }

  void _submitCustom(String raw) {
    var ext = raw.trim().toLowerCase();
    if (ext.startsWith('.')) ext = ext.substring(1);
    if (ext.isEmpty) return;
    widget.onPicked(ext);
  }
}

class _FormatTile extends StatelessWidget {
  final FormatCopy copy;
  final bool selected;
  final VoidCallback onTap;

  const _FormatTile({
    required this.copy,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.secondaryContainer : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: TeigiRadii.medium,
        side: BorderSide(
          color: copy.custom ? scheme.outline : scheme.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: TeigiRadii.medium,
        child: SizedBox(
          width: 148,
          child: Padding(
            padding: const EdgeInsets.all(TeigiSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(copy.title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  copy.summary,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact trigger that opens [FormatPicker].
class FormatPickerButton extends ConsumerWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? label;

  const FormatPickerButton({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final copy = value == null || value!.isEmpty ? null : FormatCopy.of(value!);
    final width = MediaQuery.sizeOf(context).width;
    final size = TeigiBreakpoints.sizeOf(width);

    return OutlinedButton(
      onPressed: () async {
        final picked = await FormatPicker.show(
          context,
          current: value,
          size: size,
        );
        if (picked != null) onChanged(picked);
      },
      child: Text(
        copy == null
            ? (label ?? l10n.chooseFormat)
            : '${copy.title} · ${copy.summary}',
      ),
    );
  }
}
