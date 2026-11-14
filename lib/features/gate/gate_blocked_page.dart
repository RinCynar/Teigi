import 'dart:io' show Platform, exit;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teigi/i18n/strings.dart';
import 'package:teigi_gate/teigi_gate.dart';

/// Intercept page displayed when the device fails official build validation.
class GateBlockedPage extends ConsumerWidget {
  final GateResult result;
  final VoidCallback? onExit;

  const GateBlockedPage({
    super.key,
    required this.result,
    this.onExit,
  });

  Future<void> _exitApp() async {
    if (onExit != null) {
      onExit!();
      return;
    }
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await SystemNavigator.pop();
    } else if (!kIsWeb) {
      exit(0);
    }
  }

  String _resolveMessage(L10n l10n) {
    if (result.customMessage != null && result.customMessage!.trim().isNotEmpty) {
      return result.customMessage!;
    }
    return switch (result.category) {
      GateCategory.androidSecurity => l10n.gateAndroidBlocked,
      GateCategory.windowsVendor => l10n.gateWindowsBlocked,
      GateCategory.linuxDistro => l10n.gateLinuxBlocked,
      _ => l10n.gateAndroidBlocked,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final message = _resolveMessage(l10n);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: scheme.outlineVariant.withAlpha(80),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon Badge
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: scheme.errorContainer.withAlpha(120),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.shield_outlined,
                        size: 32,
                        color: scheme.error,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    Text(
                      l10n.gateBlockedTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Body statement
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.6,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Exit Button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: FilledButton.icon(
                        key: const Key('gate-exit-button'),
                        onPressed: _exitApp,
                        icon: const Icon(Icons.exit_to_app_rounded, size: 18),
                        label: Text(
                          l10n.gateExitApp,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
