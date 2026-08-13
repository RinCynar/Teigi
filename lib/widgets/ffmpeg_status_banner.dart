import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teigi/i18n/strings.dart';
import 'package:teigi/providers/ffmpeg_provider.dart';

/// 顶部 ffmpeg 可用性横幅。
///
/// - 未就绪：常驻警示条（带「去设置」按钮）
/// - 已就绪：仅展示约 3 秒后自动淡出，避免常驻占用空间
class FfmpegStatusBanner extends ConsumerStatefulWidget {
  const FfmpegStatusBanner({super.key});

  @override
  ConsumerState<FfmpegStatusBanner> createState() => _FfmpegStatusBannerState();
}

class _FfmpegStatusBannerState extends ConsumerState<FfmpegStatusBanner> {
  static const _showDuration = Duration(seconds: 3);

  Timer? _hideTimer;
  bool _availableVisible = true;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _handleStatus(FfmpegStatus status) {
    _hideTimer?.cancel();
    if (status.isAvailable) {
      setState(() => _availableVisible = true);
      _hideTimer = Timer(_showDuration, () {
        if (mounted) setState(() => _availableVisible = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final status = ref.watch(ffmpegStatusProvider);
    ref.listen<AsyncValue<FfmpegStatus>>(ffmpegStatusProvider, (prev, next) {
      next.whenOrNull(data: _handleStatus);
    });

    return status.when(
      loading: () => const LinearProgressIndicator(minHeight: 3),
      error: (e, _) => _banner(
        context,
        color: Theme.of(context).colorScheme.error,
        icon: Icons.error_outline,
        text: l10n.detectFailed('$e'),
      ),
      data: (s) {
        if (s.isAvailable) {
          // 已就绪：展示 3 秒后淡出并收起（AnimatedSwitcher 处理过渡）。
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: _availableVisible
                ? _banner(
                    context,
                    key: const ValueKey('ready'),
                    color: Theme.of(context).colorScheme.primaryContainer,
                    icon: Icons.check_circle_outline,
                    text: l10n.ffmpegReady(s.info.version),
                    textColor: Theme.of(context).colorScheme.onPrimaryContainer,
                  )
                : const SizedBox.shrink(key: ValueKey('hidden')),
          );
        }
        return _banner(
          context,
          color: Theme.of(context).colorScheme.errorContainer,
          icon: Icons.warning_amber_outlined,
          text: s.message ?? l10n.ffmpegNotFound,
          textColor: Theme.of(context).colorScheme.onErrorContainer,
          action: TextButton(
            onPressed: () {
              ref.read(ffmpegStatusProvider.notifier).redetect();
            },
            child: Text(l10n.redetect),
          ),
        );
      },
    );
  }

  Widget _banner(
    BuildContext context, {
    Key? key,
    required Color color,
    required IconData icon,
    required String text,
    Color? textColor,
    Widget? action,
  }) {
    return Material(
      key: key,
      color: color,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: textColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: textColor),
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}
