import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teigi/core/models/conversion_options.dart';
import 'package:teigi/core/models/conversion_task.dart';
import 'package:teigi/core/models/format_preset.dart';
import 'package:teigi/features/format_config/format_selector.dart';
import 'package:teigi/features/format_config/options_editor.dart';
import 'package:teigi/i18n/strings.dart';
import 'package:teigi/providers/queue_provider.dart';
import 'package:teigi/theme/tokens.dart';

/// Desktop configuration pane. Not a 420px AlertDialog.
class ConvertConfigSheet extends ConsumerStatefulWidget {
  final ConversionTask task;
  final VoidCallback onClose;

  const ConvertConfigSheet({
    super.key,
    required this.task,
    required this.onClose,
  });

  static Future<void> open(
    BuildContext context, {
    required ConversionTask task,
    required bool asOverlay,
  }) {
    if (asOverlay) return Future.value();
    return showGeneralDialog<void>(
      context: context,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierDismissible: true,
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.32),
      transitionDuration: TeigiMotion.medium,
      pageBuilder: (ctx, _, _) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            elevation: 2,
            color: Theme.of(ctx).colorScheme.surfaceContainerLow,
            child: SizedBox(
              width: TeigiBreakpoints.configSheet,
              height: MediaQuery.sizeOf(ctx).height,
              child: ConvertConfigSheet(
                task: task,
                onClose: () => Navigator.of(ctx).pop(),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  ConsumerState<ConvertConfigSheet> createState() => _ConvertConfigSheetState();
}

class _ConvertConfigSheetState extends ConsumerState<ConvertConfigSheet> {
  late String? _format;
  late ConversionOptions _options;

  @override
  void initState() {
    super.initState();
    _format = widget.task.targetFormat;
    _options = widget.task.options;
  }

  @override
  void didUpdateWidget(covariant ConvertConfigSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.id != widget.task.id) {
      _format = widget.task.targetFormat;
      _options = widget.task.options;
    }
  }

  void _apply() {
    final notifier = ref.read(queueProvider.notifier);
    notifier.setTargetFormat(widget.task.id, _format);
    notifier.setOptions(widget.task.id, _options);
    widget.onClose();
  }

  void _applyQuality(QualityProfile quality) {
    setState(() {
      _options = _options.copyWith(
        crf: quality.crf,
        bitrateKbps: quality.audioBitrateKbps,
        imageQuality: quality.imageQuality,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TeigiSpacing.md,
            TeigiSpacing.md,
            TeigiSpacing.xs,
            TeigiSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.configure,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: l10n.cancel,
                onPressed: widget.onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: scheme.outlineVariant),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(TeigiSpacing.md),
            children: [
              Text(l10n.output, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: TeigiSpacing.xs),
              FormatSelector(
                value: _format,
                onChanged: (v) => setState(() => _format = v),
                onQuickOptionsApplied: (o) => setState(() => _options = o),
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
                emptySelectionAllowed: true,
                selected: _selectedQuality(),
                onSelectionChanged: (s) {
                  if (s.isEmpty) return;
                  final id = s.first;
                  _applyQuality(
                    QualityProfile.all.firstWhere((q) => q.id == id),
                  );
                },
              ),
              const SizedBox(height: TeigiSpacing.lg),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(l10n.advanced),
                children: [
                  if (_format != null)
                    OptionsForm(
                      targetFormat: _format,
                      initial: _options,
                      onChanged: (o) => _options = o,
                    ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(TeigiSpacing.md),
          child: FilledButton(
            onPressed: _apply,
            child: Text(l10n.apply),
          ),
        ),
      ],
    );
  }

  Set<String> _selectedQuality() {
    final crf = _options.crf;
    for (final q in QualityProfile.all) {
      if (q.crf == crf) return {q.id};
    }
    return {};
  }
}
