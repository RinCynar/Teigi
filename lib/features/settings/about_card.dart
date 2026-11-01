import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teigi/i18n/strings.dart';
import 'package:teigi/providers/app_info_provider.dart';
import 'package:teigi/theme/tokens.dart';
import 'package:url_launcher/url_launcher.dart';

/// 嵌入在设置页底部的关于信息卡片，对齐 0rhxPlayer-Desktop 的设计规范。
class AboutCard extends ConsumerWidget {
  const AboutCard({super.key});

  static const developerName = 'RinCynar';
  static const developerUrl = 'https://rincynar.top';
  static const repositoryUrl = 'https://github.com/RinCynar/Teigi';
  static const repositoryName = 'RinCynar/Teigi';
  static const websiteUrl = 'https://teigi.rincynar.top';
  static const websiteHost = 'teigi.rincynar.top';
  static const licenseName = 'MIT License';

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _copy(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final version = ref.watch(appVersionProvider);
    final scheme = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: TeigiRadii.card,
        side: BorderSide(color: scheme.borderSubtle, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 14 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 卡片头部
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.aboutTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 应用横幅
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.movie_filter_rounded,
                    size: 26,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Teigi',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: scheme.onSurface,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'v$version',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: scheme.onPrimaryContainer,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.openSourceDesc.split('\n').first,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(height: 1, thickness: 1, color: scheme.borderSubtle),
            const SizedBox(height: 12),

            // 开发者
            _InfoRow(
              label: l10n.developer,
              value: developerName,
              isInteractive: true,
              onTap: () => _launch(developerUrl),
            ),
            const SizedBox(height: 8),

            // 开源项目地址
            _InfoRow(
              label: l10n.projectUrl,
              value: repositoryName,
              isInteractive: true,
              onTap: () => _launch(repositoryUrl),
              onCopy: () => _copy(context, repositoryUrl, l10n.linkCopied),
            ),
            const SizedBox(height: 8),

            // 项目官方网站
            _InfoRow(
              label: l10n.website,
              value: websiteHost,
              isInteractive: true,
              onTap: () => _launch(websiteUrl),
              onCopy: () => _copy(context, websiteUrl, l10n.linkCopied),
            ),
            const SizedBox(height: 8),

            // 开源协议
            _InfoRow(
              label: l10n.license,
              value: licenseName,
              isInteractive: false,
            ),
            const SizedBox(height: 12),
            Divider(height: 1, thickness: 1, color: scheme.borderSubtle),
            const SizedBox(height: 12),

            // 开源声明详情
            Text(
              l10n.openSourceDesc,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isInteractive;
  final VoidCallback? onTap;
  final VoidCallback? onCopy;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isInteractive = false,
    this.onTap,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: isInteractive
                      ? InkWell(
                          onTap: onTap,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Text(
                              value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: scheme.primary,
                                  ),
                            ),
                          ),
                        )
                      : Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurface,
                                  ),
                        ),
                ),
                if (onCopy != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 24, minHeight: 24),
                    splashRadius: 14,
                    tooltip: 'Copy',
                    onPressed: onCopy,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
