/// Device gatekeeper contract and stub implementation for Teigi.
library;

/// The category of device gate rejection.
enum GateCategory {
  /// Blocked on Android: Device does not pass Google security certification.
  androidSecurity,

  /// Blocked on Windows: Hardware vendor is Huawei.
  windowsVendor,

  /// Blocked on Linux: Operating system distribution is in the blocked list.
  linuxDistro,
}

/// The result of an official build device gate check.
class GateResult {
  /// Whether the device is allowed to proceed to normal application flows.
  final bool isAllowed;

  /// The rejection category if blocked.
  final GateCategory? category;

  /// Optional specific rejection message.
  final String? customMessage;

  const GateResult.passed()
      : isAllowed = true,
        category = null,
        customMessage = null;

  const GateResult.blocked({
    required this.category,
    this.customMessage,
  }) : isAllowed = false;

  /// Convenient getter indicating if the device is blocked.
  bool get isBlocked => !isAllowed;

  @override
  String toString() {
    if (isAllowed) return 'GateResult(allowed)';
    return 'GateResult(blocked: category=$category, message=$customMessage)';
  }
}

/// Abstract contract for device gatekeeper checks.
abstract class Gatekeeper {
  /// Current active gatekeeper instance.
  /// Defaults to [StubGatekeeper] which always passes.
  static Gatekeeper instance = const StubGatekeeper();

  /// Runs the gatekeeper check for the current platform and returns the [GateResult].
  Future<GateResult> check();
}

/// Stub gatekeeper that always allows execution on all platforms.
class StubGatekeeper implements Gatekeeper {
  const StubGatekeeper();

  @override
  Future<GateResult> check() async => const GateResult.passed();
}
