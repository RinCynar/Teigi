import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teigi/core/models/batch_options_patch.dart';
import 'package:teigi/i18n/strings.dart';
import 'package:teigi/providers/queue_provider.dart';
import 'package:teigi/theme/tokens.dart';

class BatchConfigSheet extends ConsumerStatefulWidget {
  final Set<String> ids;
  final VoidCallback onClose;

  const BatchConfigSheet({super.key, required this.ids, required this.onClose});

  static Future<void> open(
    BuildContext context, {
    required Set<String> ids,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.32),
      pageBuilder: (ctx, _, _) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            elevation: 2,
            color: Theme.of(ctx).colorScheme.surfaceContainerLow,
            child: SizedBox(
              width: TeigiBreakpoints.configSheet,
              height: MediaQuery.sizeOf(ctx).height,
              child: BatchConfigSheet(
                ids: ids,
                onClose: () => Navigator.of(ctx).pop(),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  ConsumerState<BatchConfigSheet> createState() => _BatchConfigSheetState();
}

class _BatchConfigSheetState extends ConsumerState<BatchConfigSheet> {
  FieldPatch<String?> _encoder = const Unchanged();
  FieldPatch<int?> _crf = const Unchanged();
  FieldPatch<String?> _resolution = const Unchanged();
  FieldPatch<int?> _bitrate = const Unchanged();
  FieldPatch<int?> _sampleRate = const Unchanged();
  FieldPatch<int?> _channels = const Unchanged();

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final n = widget.ids.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(TeigiSpacing.md),
          child: Text(
            l10n.configureNFiles(n),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(TeigiSpacing.md),
            children: [
              Text(l10n.video, style: Theme.of(context).textTheme.labelLarge),
              _PatchString(
                label: l10n.encoder,
                patch: _encoder,
                values: const ['libx264', 'libx265', 'libvpx-vp9'],
                onChanged: (p) => setState(() => _encoder = p),
              ),
              _PatchInt(
                label: l10n.qualityCrf,
                patch: _crf,
                values: const [18, 20, 23, 28],
                onChanged: (p) => setState(() => _crf = p),
              ),
              _PatchString(
                label: l10n.resolution,
                patch: _resolution,
                values: const ['1920x1080', '1280x720'],
                onChanged: (p) => setState(() => _resolution = p),
              ),
              const SizedBox(height: TeigiSpacing.md),
              Text(l10n.audio, style: Theme.of(context).textTheme.labelLarge),
              _PatchInt(
                label: l10n.bitrate,
                patch: _bitrate,
                values: const [128, 192, 256, 320],
                onChanged: (p) => setState(() => _bitrate = p),
              ),
              _PatchInt(
                label: l10n.sampleRate,
                patch: _sampleRate,
                values: const [44100, 48000],
                onChanged: (p) => setState(() => _sampleRate = p),
              ),
              _PatchInt(
                label: l10n.channels,
                patch: _channels,
                values: const [1, 2],
                onChanged: (p) => setState(() => _channels = p),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(TeigiSpacing.md),
          child: Row(
            children: [
              TextButton(onPressed: widget.onClose, child: Text(l10n.cancel)),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  ref.read(queueProvider.notifier).applyPatch(
                        widget.ids,
                        BatchOptionsPatch(
                          videoEncoder: _encoder,
                          crf: _crf,
                          resolution: _resolution,
                          bitrateKbps: _bitrate,
                          sampleRate: _sampleRate,
                          channels: _channels,
                        ),
                      );
                  widget.onClose();
                },
                child: Text(l10n.applyToFiles(n)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PatchString extends ConsumerWidget {
  final String label;
  final FieldPatch<String?> patch;
  final List<String> values;
  final ValueChanged<FieldPatch<String?>> onChanged;

  const _PatchString({
    required this.label,
    required this.patch,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final mode = switch (patch) {
      Unchanged<String?>() => 'unchanged',
      SetAuto<String?>() => 'auto',
      SetValue<String?>(:final value) => value ?? 'auto',
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label),
      trailing: DropdownButton<String>(
        value: mode,
        items: [
          DropdownMenuItem(value: 'unchanged', child: Text(l10n.unchanged)),
          DropdownMenuItem(value: 'auto', child: Text(l10n.auto)),
          for (final v in values) DropdownMenuItem(value: v, child: Text(v)),
        ],
        onChanged: (v) {
          if (v == null || v == 'unchanged') {
            onChanged(const Unchanged());
          } else if (v == 'auto') {
            onChanged(const SetAuto());
          } else {
            onChanged(SetValue(v));
          }
        },
      ),
    );
  }
}

class _PatchInt extends ConsumerWidget {
  final String label;
  final FieldPatch<int?> patch;
  final List<int> values;
  final ValueChanged<FieldPatch<int?>> onChanged;

  const _PatchInt({
    required this.label,
    required this.patch,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final mode = switch (patch) {
      Unchanged<int?>() => 'unchanged',
      SetAuto<int?>() => 'auto',
      SetValue<int?>(:final value) => '${value ?? ''}',
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label),
      trailing: DropdownButton<String>(
        value: values.map((e) => '$e').contains(mode) ||
                mode == 'unchanged' ||
                mode == 'auto'
            ? mode
            : 'unchanged',
        items: [
          DropdownMenuItem(value: 'unchanged', child: Text(l10n.unchanged)),
          DropdownMenuItem(value: 'auto', child: Text(l10n.auto)),
          for (final v in values)
            DropdownMenuItem(value: '$v', child: Text('$v')),
        ],
        onChanged: (v) {
          if (v == null || v == 'unchanged') {
            onChanged(const Unchanged());
          } else if (v == 'auto') {
            onChanged(const SetAuto());
          } else {
            onChanged(SetValue(int.tryParse(v)));
          }
        },
      ),
    );
  }
}
