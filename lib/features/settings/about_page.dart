import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teigi/i18n/strings.dart';
import 'package:url_launcher/url_launcher.dart';

/// 关于界面：应用信息、开发者、项目地址、项目网站、开源声明。
class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  static const developerName = 'RinCynar';
  static const repositoryUrl = 'https://github.com/RinCynar/Teigi';
  static const websiteUrl = 'https://teigi.rincynar.top';
  static const appVersion = '1.0.0';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aboutTitle),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(Icons.movie_filter, size: 48, color: scheme.primary),
                ),
                const SizedBox(height: 12),
                Text('Teigi', style: Theme.of(context).textTheme.headlineMedium),
                Text(
                  'v$appVersion',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _InfoCard(
            icon: Icons.person_outline,
            label: l10n.developer,
            value: developerName,
          ),
          const SizedBox(height: 12),
          _LinkCard(
            icon: Icons.code,
            label: l10n.projectUrl,
            value: repositoryUrl,
            onTap: () => launchUrl(Uri.parse(repositoryUrl)),
            onCopy: () => _copy(context, repositoryUrl),
          ),
          const SizedBox(height: 12),
          _LinkCard(
            icon: Icons.language,
            label: l10n.website,
            value: websiteUrl,
            onTap: () => launchUrl(Uri.parse(websiteUrl)),
            onCopy: () => _copy(context, websiteUrl),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.volunteer_activism_outlined, size: 20, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text(l10n.openSource,
                          style: Theme.of(context).textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.openSourceDesc,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Teigi v$appVersion',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.outline),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text)),
      );
    }
  }
}

/// 信息卡片。
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(icon, color: scheme.primary),
        title: Text(label, style: Theme.of(context).textTheme.bodySmall),
        subtitle: Text(value),
      ),
    );
  }
}

/// 可点击/复制的链接卡片。
class _LinkCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback onCopy;

  const _LinkCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(icon, color: scheme.primary),
        title: Text(label, style: Theme.of(context).textTheme.bodySmall),
        subtitle: Text(value),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.copy_outlined, size: 18),
              tooltip: 'Copy',
              onPressed: onCopy,
            ),
            IconButton(
              icon: const Icon(Icons.open_in_new, size: 18),
              tooltip: 'Open',
              onPressed: onTap,
            ),
          ],
        ),
      ),
    );
  }
}
