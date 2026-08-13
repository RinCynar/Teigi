import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teigi/features/home/home_page.dart';
import 'package:teigi/features/settings/about_page.dart';
import 'package:teigi/features/settings/settings_page.dart';
import 'package:teigi/i18n/strings.dart';
import 'package:teigi/providers/settings_provider.dart';
import 'package:teigi/theme/teigi_theme.dart';

/// 路由表。
final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: '/about',
      name: 'about',
      builder: (context, state) => const AboutPage(),
    ),
  ],
);

/// Teigi 应用根组件。
class TeigiApp extends ConsumerWidget {
  const TeigiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final l10n = ref.watch(l10nProvider);

    return MaterialApp.router(
      title: l10n.appTitle,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: TeigiTheme.light(seed: settings.seedColor, language: settings.language),
      darkTheme: TeigiTheme.dark(seed: settings.seedColor, language: settings.language),
      themeMode: switch (settings.themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
    );
  }
}
