import 'package:local_auth/local_auth.dart';

enum AuthOutcome {
  success,

  /// Cancelled, not recognised, or temporarily locked out.
  failed,

  /// The phone cannot authenticate at all (for example no screen lock).
  unavailable,
}

abstract class BiometricAuthenticator {
  Future<bool> isSupported();
  Future<AuthOutcome> authenticate(String reason);
}

class LocalAuthAuthenticator implements BiometricAuthenticator {
  LocalAuthAuthenticator([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<AuthOutcome> authenticate(String reason) async {
    try {
      // Fingerprint or face, with the phone's PIN or pattern as a fallback.
      final ok = await _auth.authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
      );
      return ok ? AuthOutcome.success : AuthOutcome.failed;
    } catch (_) {
      // A cancelled or failed attempt may throw. It only counts as
      // "unavailable" when the phone can no longer authenticate at all.
      return await isSupported() ? AuthOutcome.failed : AuthOutcome.unavailable;
    }
  }
}