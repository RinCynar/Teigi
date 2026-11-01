import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teigi/core/services/sharing_intent_service.dart';
import 'package:teigi/features/convert/convert_page.dart';
import 'package:teigi/features/convert/media_import.dart';
import 'package:teigi/i18n/strings.dart';
import 'package:teigi/providers/queue_provider.dart';
import 'package:teigi/providers/recent_presets_provider.dart';
import 'package:teigi/shared/widgets/teigi_mark.dart';
import 'package:teigi/providers/settings_provider.dart';
import 'package:teigi/theme/tokens.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  static const locations = ['/convert', '/queue', '/presets', '/settings'];

  /// Public so tests can assert About stays on Settings.
  static int indexFor(String path) {
    if (path.startsWith('/settings')) return 3;
    if (path.startsWith('/queue')) return 1;
    if (path.startsWith('/presets')) return 2;
    if (path.startsWith('/convert')) return 0;
    return 0;
  }

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _dragOver = false;
  static const _import = MediaImport();

  @override
  void initState() {
    super.initState();
    SharingIntentService.instance.init(
      onFilesReceived: (files) {
        if (!mounted || files.isEmpty) return;
        final pending = ref.read(pendingPresetProvider);
        ref.read(queueProvider.notifier).addFiles(files, preset: pending);
        if (pending != null) {
          ref.read(pendingPresetProvider.notifier).state = null;
        }
        context.go('/convert');
      },
    );
  }

  @override
  void dispose() {
    SharingIntentService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final path = GoRouterState.of(context).uri.path;
    final selected = AppShell.indexFor(path);
    final width = MediaQuery.sizeOf(context).width;
    final size = TeigiBreakpoints.sizeOf(width);
    final scheme = Theme.of(context).colorScheme;

    final settings = ref.watch(settingsProvider);
    final extended = settings.sidebarExpanded && size != TeigiWindowSize.compact;

    final destinations = [
      _Dest(Icons.sync_alt, Icons.sync_alt, l10n.navConvert),
      _Dest(Icons.queue_outlined, Icons.queue, l10n.navQueue),
      _Dest(Icons.bookmark_outline, Icons.bookmark, l10n.navPresets),
      _Dest(Icons.settings_outlined, Icons.settings, l10n.navSettings),
    ];

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyO, control: true): _pickFiles,
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
          // 与转换页按钮共用守卫：任务未指定格式时先弹窗确认。
          ConvertPage.startConversion(context, ref);
        },
        const SingleActivator(LogicalKeyboardKey.comma, control: true): () {
          context.go('/settings');
        },
      },
      child: Focus(
        autofocus: true,
        child: DropTarget(
          onDragEntered: (_) => setState(() => _dragOver = true),
          onDragExited: (_) => setState(() => _dragOver = false),
          onDragDone: (details) async {
            setState(() => _dragOver = false);
            final router = GoRouter.of(context);
            final files = await _import.fromDropped(details.files);
            if (files.isEmpty) return;
            final pending = ref.read(pendingPresetProvider);
            ref.read(queueProvider.notifier).addFiles(files, preset: pending);
            if (pending != null) {
              ref.read(pendingPresetProvider.notifier).state = null;
            }
            router.go('/convert');
          },
          child: Stack(
            children: [
              Scaffold(
                body: SafeArea(
                  top: true,
                  bottom: size != TeigiWindowSize.compact,
                  child: Row(
                    children: [
                      if (size != TeigiWindowSize.compact)
                        RepaintBoundary(
                          child: NavigationRail(
                            selectedIndex: selected,
                            extended: extended,
                            minWidth: 72,
                            minExtendedWidth: 220,
                            labelType: extended ? null : NavigationRailLabelType.none,
                            onDestinationSelected: (i) => context.go(AppShell.locations[i]),
                            leading: _SidebarHeader(
                              extended: extended,
                              onToggle: () => ref.read(settingsProvider.notifier).toggleSidebar(),
                            ),
                            destinations: [
                              for (final d in destinations)
                                NavigationRailDestination(
                                  icon: Icon(d.icon),
                                  selectedIcon: Icon(d.selectedIcon),
                                  label: Text(d.label),
                                ),
                            ],
                          ),
                        ),
                      if (size != TeigiWindowSize.compact)
                        VerticalDivider(width: 1, thickness: 1, color: scheme.borderSubtle),
                      Expanded(
                        child: RepaintBoundary(child: widget.child),
                      ),
                    ],
                  ),
                ),
                bottomNavigationBar: size == TeigiWindowSize.compact
                    ? NavigationBar(
                        selectedIndex:
                            selected.clamp(0, destinations.length - 1),
                        destinations: [
                          for (final d in destinations)
                            NavigationDestination(
                              icon: Icon(d.icon),
                              selectedIcon: Icon(d.selectedIcon),
                              label: d.label,
                            ),
                        ],
                        onDestinationSelected: (i) => context.go(AppShell.locations[i]),
                      )
                    : null,
              ),
              if (_dragOver)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: scheme.scrim.withValues(alpha: 0.18),
                      child: Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: TeigiRadii.extraLarge,
                            border: Border.all(color: scheme.primary, width: 2),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: TeigiSpacing.xxl,
                              vertical: TeigiSpacing.xl,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.south,
                                  size: 36,
                                  color: scheme.primary,
                                ),
                                const SizedBox(height: TeigiSpacing.sm),
                                Text(
                                  l10n.releaseToAdd,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFiles() async {
    final router = GoRouter.of(context);
    final files = await _import.pickFiles();
    if (files.isEmpty) return;
    final pending = ref.read(pendingPresetProvider);
    ref.read(queueProvider.notifier).addFiles(files, preset: pending);
    if (pending != null) {
      ref.read(pendingPresetProvider.notifier).state = null;
    }
    router.go('/convert');
  }
}

class _Dest {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _Dest(this.icon, this.selectedIcon, this.label);
}

class _SidebarHeader extends StatelessWidget {
  final bool extended;
  final VoidCallback onToggle;

  const _SidebarHeader({
    required this.extended,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (!extended) {
      return SizedBox(
        width: 72,
        height: 52,
        child: Center(
          child: IconButton(
            key: const Key('sidebar-toggle-btn'),
            icon: const Icon(Icons.menu_rounded, size: 22),
            tooltip: 'Expand sidebar',
            splashRadius: 20,
            onPressed: onToggle,
          ),
        ),
      );
    }

    return SizedBox(
      width: 220,
      height: 52,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TeigiMark(size: 24),
            const SizedBox(width: 8),
            Text(
              'Teigi',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
            ),
            const SizedBox(width: 16),
            IconButton(
              key: const Key('sidebar-toggle-btn'),
              icon: const Icon(Icons.chevron_left_rounded, size: 20),
              tooltip: 'Collapse sidebar',
              splashRadius: 18,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: onToggle,
            ),
          ],
        ),
      ),
    );
  }
}
