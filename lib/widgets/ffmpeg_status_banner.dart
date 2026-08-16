import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teigi/i18n/strings.dart';
import 'package:teigi/providers/ffmpeg_provider.dart';
import 'package:teigi/theme/tokens.dart';

/// Visible only when FFmpeg is missing or still being checked.
class FfmpegStatusBanner extends ConsumerWidget {
  const FfmpegStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final status = ref.watch(ffmpegStatusProvider);
    final scheme = Theme.of(context).colorScheme;

    return status.when(
      loading: () => Padding(
        padding: const EdgeInsets.only(bottom: TeigiSpacing.sm),
        child: Text(
          l10n.checkingFfmpeg,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
      error: (e, _) => _MissingBar(
        text: l10n.detectFailed('$e'),
        actionLabel: l10n.navSettings,
        onAction: () => context.go('/settings'),
      ),
      data: (s) {
        if (s.isAvailable) return const SizedBox.shrink();
        return _MissingBar(
          text: l10n.ffmpegNotConfigured,
          actionLabel: l10n.navSettings,
          onAction: () => context.go('/settings'),
        );
      },
    );
  }
}

class _MissingBar extends StatelessWidget {
  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  const _MissingBar({
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: TeigiSpacing.md),
      child: Material(
        color: scheme.errorContainer,
        borderRadius: TeigiRadii.medium,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            TeigiSpacing.md,
            TeigiSpacing.sm,
            TeigiSpacing.xs,
            TeigiSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_outlined,
                size: 18,
                color: scheme.onErrorContainer,
              ),
              const SizedBox(width: TeigiSpacing.xs),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onErrorContainer),
                ),
              ),
              TextButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ),
        ),
      ),
    );
  }
}
