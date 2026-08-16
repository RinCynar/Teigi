import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teigi/features/convert/media_import.dart';
import 'package:teigi/i18n/strings.dart';
import 'package:teigi/providers/conversion_engine.dart';
import 'package:teigi/providers/queue_provider.dart';
import 'package:teigi/theme/tokens.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _dragOver = false;
  static const _import = MediaImport();

  static const _locations = ['/convert', '/queue', '/presets', '/settings'];

  int _indexFor(String path) {
    final i = _locations.indexWhere((l) => path.startsWith(l));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final path = GoRouterState.of(context).uri.path;
    final selected = _indexFor(path);
    final width = MediaQuery.sizeOf(context).width;
    final size = TeigiBreakpoints.sizeOf(width);

    final destinations = [
      _Dest(Icons.transform, Icons.transform, l10n.navConvert),
      _Dest(Icons.queue_outlined, Icons.queue, l10n.navQueue),
      _Dest(Icons.bookmark_outline, Icons.bookmark, l10n.navPresets),
      _Dest(Icons.settings_outlined, Icons.settings, l10n.navSettings),
    ];

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyO, control: true): () {
          _pickFiles();
        },
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
          ref.read(conversionEngineProvider).start();
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
            ref.read(queueProvider.notifier).addFiles(files);
            router.go('/convert');
          },
          child: Stack(
            children: [
              Scaffold(
                body: Row(
                  children: [
                    if (size != TeigiWindowSize.compact)
                      NavigationRail(
                        selectedIndex: selected,
                        extended: size == TeigiWindowSize.expanded,
                        labelType: size == TeigiWindowSize.expanded
                            ? NavigationRailLabelType.none
                            : NavigationRailLabelType.all,
                        onDestinationSelected: (i) => context.go(_locations[i]),
                        leading: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: TeigiSpacing.sm,
                          ),
                          child: Tooltip(
                            message: l10n.appTitle,
                            child: Icon(
                              Icons.movie_filter_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        destinations: [
                          for (final d in destinations)
                            NavigationRailDestination(
                              icon: Icon(d.icon),
                              selectedIcon: Icon(d.selectedIcon),
                              label: Text(d.label),
                            ),
                        ],
                        trailing: IconButton(
                          tooltip: l10n.about,
                          icon: const Icon(Icons.info_outline),
                          onPressed: () => context.go('/about'),
                        ),
                      ),
                    const VerticalDivider(width: 1),
                    Expanded(child: widget.child),
                  ],
                ),
                bottomNavigationBar: size == TeigiWindowSize.compact
                    ? NavigationBar(
                        selectedIndex: selected.clamp(0, destinations.length - 1),
                        destinations: [
                          for (final d in destinations)
                            NavigationDestination(
                              icon: Icon(d.icon),
                              selectedIcon: Icon(d.selectedIcon),
                              label: d.label,
                            ),
                        ],
                        onDestinationSelected: (i) => context.go(_locations[i]),
                      )
                    : null,
              ),
              if (_dragOver)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: 0.92),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.file_download_outlined,
                              size: 64,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                            const SizedBox(height: TeigiSpacing.md),
                            Text(
                              l10n.dropFiles,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ],
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
    ref.read(queueProvider.notifier).addFiles(files);
    router.go('/convert');
  }
}

class _Dest {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _Dest(this.icon, this.selectedIcon, this.label);
}
