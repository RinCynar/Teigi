import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teigi/app.dart';
import 'package:teigi/core/models/app_settings.dart';
import 'package:teigi/features/gate/gate_blocked_page.dart';
import 'package:teigi/providers/settings_provider.dart';
import 'package:teigi_gate/teigi_gate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    setActiveGateResult(const GateResult.passed());
    router.go('/convert');
  });

  tearDown(() {
    setActiveGateResult(const GateResult.passed());
  });

  group('GateBlockedPage Widget Tests', () {
    testWidgets('renders Android security check message in Chinese', (tester) async {
      SharedPreferences.setMockInitialValues({'language': 'zh'});
      final prefs = await SharedPreferences.getInstance();
      final settings = await AppSettings.load(prefs);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith(
              (ref) => SettingsNotifier(settings, prefs),
            ),
          ],
          child: const MaterialApp(
            home: GateBlockedPage(
              result: GateResult.blocked(
                category: GateCategory.androidSecurity,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('设备不受支持'), findsOneWidget);
      expect(find.text('本应用仅支持通过 Google 安全认证的设备。'), findsOneWidget);
      expect(find.text('退出'), findsOneWidget);
    });

    testWidgets('renders Windows Huawei message in Chinese', (tester) async {
      SharedPreferences.setMockInitialValues({'language': 'zh'});
      final prefs = await SharedPreferences.getInstance();
      final settings = await AppSettings.load(prefs);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith(
              (ref) => SettingsNotifier(settings, prefs),
            ),
          ],
          child: const MaterialApp(
            home: GateBlockedPage(
              result: GateResult.blocked(
                category: GateCategory.windowsVendor,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('本软件的官方构建不支持华为设备。作者不喜欢华为。如果你需要在华为设备上使用，请自行编译源代码。'),
        findsOneWidget,
      );
      expect(find.text('退出'), findsOneWidget);
    });

    testWidgets('renders Linux distro message in Chinese', (tester) async {
      SharedPreferences.setMockInitialValues({'language': 'zh'});
      final prefs = await SharedPreferences.getInstance();
      final settings = await AppSettings.load(prefs);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith(
              (ref) => SettingsNotifier(settings, prefs),
            ),
          ],
          child: const MaterialApp(
            home: GateBlockedPage(
              result: GateResult.blocked(
                category: GateCategory.linuxDistro,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('本软件的官方构建不支持当前 Linux 发行版。如果你需要使用，请自行编译源代码。'),
        findsOneWidget,
      );
      expect(find.text('退出'), findsOneWidget);
    });

    testWidgets('renders English translations when language is en', (tester) async {
      SharedPreferences.setMockInitialValues({'language': 'en'});
      final prefs = await SharedPreferences.getInstance();
      final settings = await AppSettings.load(prefs);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith(
              (ref) => SettingsNotifier(settings, prefs),
            ),
          ],
          child: const MaterialApp(
            home: GateBlockedPage(
              result: GateResult.blocked(
                category: GateCategory.windowsVendor,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unsupported Device'), findsOneWidget);
      expect(
        find.text(
          'Official builds of this software do not support Huawei devices. The author dislikes Huawei. If you need to use it on a Huawei device, please compile from source code.',
        ),
        findsOneWidget,
      );
      expect(find.text('Exit'), findsOneWidget);
    });

    testWidgets('triggers onExit callback when Exit button is pressed', (tester) async {
      SharedPreferences.setMockInitialValues({'language': 'zh'});
      final prefs = await SharedPreferences.getInstance();
      final settings = await AppSettings.load(prefs);

      var exitCalled = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith(
              (ref) => SettingsNotifier(settings, prefs),
            ),
          ],
          child: MaterialApp(
            home: GateBlockedPage(
              result: const GateResult.blocked(
                category: GateCategory.windowsVendor,
              ),
              onExit: () {
                exitCalled = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('gate-exit-button')));
      await tester.pump();
      expect(exitCalled, isTrue);
    });
  });

  group('Router Gate Interception Tests', () {
    testWidgets('redirects to /blocked when activeGateResult is blocked', (tester) async {
      SharedPreferences.setMockInitialValues({'language': 'zh'});
      final prefs = await SharedPreferences.getInstance();
      final settings = await AppSettings.load(prefs);

      setActiveGateResult(
        const GateResult.blocked(category: GateCategory.windowsVendor),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith(
              (ref) => SettingsNotifier(settings, prefs),
            ),
          ],
          child: const TeigiApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(router.state.matchedLocation, '/blocked');
      expect(find.text('设备不受支持'), findsOneWidget);

      // Attempting to navigate to /convert or /settings must be intercepted back to /blocked
      router.go('/convert');
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, '/blocked');

      router.go('/settings');
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, '/blocked');
    });
  });
}
