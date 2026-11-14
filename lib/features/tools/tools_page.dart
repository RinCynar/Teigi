import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teigi/i18n/strings.dart';
import 'package:teigi/shared/layout/content_constraint.dart';
import 'package:teigi/theme/tokens.dart';

/// 工具箱页面：统一网格卡片流展示独立工具入口。
class ToolsPage extends ConsumerWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final width = MediaQuery.sizeOf(context).width;
    final size = TeigiBreakpoints.sizeOf(width);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ContentConstraint(
          padding: EdgeInsets.fromLTRB(
            size == TeigiWindowSize.compact ? TeigiSpacing.md : TeigiSpacing.page,
            TeigiSpacing.lg,
            size == TeigiWindowSize.compact ? TeigiSpacing.md : TeigiSpacing.page,
            TeigiSpacing.page,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.navTools,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: TeigiSpacing.lg),
              Expanded(
                child: GridView.count(
                  crossAxisCount: size == TeigiWindowSize.compact
                      ? 1
                      : (width < 960 ? 2 : 3),
                  mainAxisSpacing: TeigiSpacing.md,
                  crossAxisSpacing: TeigiSpacing.md,
                  childAspectRatio: size == TeigiWindowSize.compact ? 2.8 : 2.2,
                  children: [
                    _ToolCard(
                      icon: Icons.lock_open_rounded,
                      title: l10n.toolNcmTitle,
                      description: l10n.toolNcmDesc,
                      badge: l10n.audioTool,
                      onTap: () => context.go('/tools/ncm'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? badge;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.title,
    required this.description,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: TeigiRadii.card,
      elevation: 0,
      child: InkWell(
        borderRadius: TeigiRadii.card,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(TeigiSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: TeigiRadii.card,
            border: Border.all(color: scheme.borderSubtle, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: scheme.primary, size: 20),
                  ),
                  const SizedBox(width: TeigiSpacing.sm),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge!,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onSecondaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: TeigiSpacing.sm),
              Expanded(
                child: Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
