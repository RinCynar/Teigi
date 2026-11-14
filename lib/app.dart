import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teigi/features/convert/convert_page.dart';
import 'package:teigi/features/gate/gate_blocked_page.dart';
import 'package:teigi/features/presets/presets_page.dart';
import 'package:teigi/features/queue/queue_panel.dart';
import 'package:teigi/features/settings/settings_page.dart';
import 'package:teigi/i18n/strings.dart';
import 'package:teigi/providers/settings_provider.dart';
import 'package:teigi/shared/layout/app_shell.dart';
import 'package:teigi/theme/teigi_theme.dart';
import 'package:teigi_gate/teigi_gate.dart';

/// Active gatekeeper result. Defaults to passed.
GateResult activeGateResult = const GateResult.passed();

/// Provider for listening to current gate result.
final gateResultProvider = StateProvider<GateResult>((ref) => activeGateResult);

/// Sets active gate result and triggers router redirection.
void setActiveGateResult(GateResult result) {
  activeGateResult = result;
  router.refresh();
}

final router = GoRouter(
  initialLocation: '/convert',
  redirect: (context, state) {
    if (activeGateResult.isBlocked) {
      if (state.matchedLocation != '/blocked') {
        return '/blocked';
      }
      return null;
    }
    if (state.matchedLocation == '/blocked') {
      return '/convert';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/', redirect: (_, _) => '/convert'),
    GoRoute(
      path: '/blocked',
      name: 'blocked',
      builder: (context, state) => GateBlockedPage(result: activeGateResult),
    ),
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
              redirect: (_, _) => '/settings',
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
