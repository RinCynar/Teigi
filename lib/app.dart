import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teigi/features/convert/convert_page.dart';
import 'package:teigi/features/presets/presets_page.dart';
import 'package:teigi/features/queue/queue_panel.dart';
import 'package:teigi/features/settings/about_page.dart';
import 'package:teigi/features/settings/settings_page.dart';
import 'package:teigi/i18n/strings.dart';
import 'package:teigi/providers/settings_provider.dart';
import 'package:teigi/shared/layout/app_shell.dart';
import 'package:teigi/theme/teigi_theme.dart';

final router = GoRouter(
  initialLocation: '/convert',
  routes: [
    GoRoute(path: '/', redirect: (_, _) => '/convert'),
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/convert',
          name: 'convert',
          builder: (context, state) => const ConvertPage(),
        ),
        GoRoute(
          path: '/queue',
          name: 'queue',
          builder: (context, state) => const QueuePanel(),
        ),
        GoRoute(
          path: '/presets',
          name: 'presets',
          builder: (context, state) => const PresetsPage(),
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (context, state) => const SettingsPage(),
          routes: [
            GoRoute(
              path: 'about',
              name: 'about',
              builder: (context, state) => const AboutPage(),
            ),
          ],
        ),
      ],
    ),
  ],
);

class TeigiApp extends ConsumerWidget {
  const TeigiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final l10n = ref.watch(l10nProvider);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp.router(
          title: l10n.appTitle,
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          theme: TeigiTheme.light(
            colorScheme: lightDynamic,
            language: l10n.language,
          ),
          darkTheme: TeigiTheme.dark(
            colorScheme: darkDynamic,
            language: l10n.language,
          ),
          themeMode: switch (settings.themeMode) {
            'light' => ThemeMode.light,
            'dark' => ThemeMode.dark,
            _ => ThemeMode.system,
          },
        );
      },
    );
  }
}
