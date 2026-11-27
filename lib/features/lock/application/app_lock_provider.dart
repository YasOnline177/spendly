import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_provider.dart';
import '../data/app_lock_store.dart';
import '../data/biometric_authenticator.dart';
import 'lock_rules.dart';

final appLockStoreProvider = Provider<AppLockStore>(
  (ref) => SharedPreferencesAppLockStore(),
);

final biometricAuthenticatorProvider = Provider<BiometricAuthenticator>(
  (ref) => LocalAuthAuthenticator(),
);

class AppLockState {
  const AppLockState({
    required this.enabled,
    required this.locked,
    this.unavailable = false,
  });

  final bool enabled;
  final bool locked;

  /// The phone could not verify the user (no screen lock set up any more).
  final bool unavailable;

  AppLockState copyWith({bool? enabled, bool? locked, bool? unavailable}) {
    return AppLockState(
      enabled: enabled ?? this.enabled,
      locked: locked ?? this.locked,
      unavailable: unavailable ?? this.unavailable,
    );
  }
}

enum LockChange { done, unsupported, failed }

class AppLockController extends AsyncNotifier<AppLockState> {
  DateTime? _backgroundedAt;
  bool _authenticating = false;

  AppLockStore get _store => ref.read(appLockStoreProvider);
  BiometricAuthenticator get _auth => ref.read(biometricAuthenticatorProvider);

  @override
  Future<AppLockState> build() async {
    final enabled = await ref.watch(appLockStoreProvider).isEnabled();

    final user = await ref.watch(authStateProvider.future);

    return AppLockState(
      enabled: enabled,
      locked: enabled && (user?.emailVerified ?? false),
    );
  }

  /// Nobody verified is signed in, so there is nothing to protect.
  void clearLock() {
    final current = state.value;
    _backgroundedAt = null;
    if (current == null || !current.locked) return;
    state = AsyncData(current.copyWith(locked: false, unavailable: false));
  }

  void onBackgrounded(DateTime now) {
    if (_authenticating) return; // the prompt itself can pause the app
    _backgroundedAt ??= now;
  }

  void onResumed(DateTime now, {required bool signedIn}) {
    if (_authenticating) return;

    final current = state.value;
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (current == null || !signedIn) return;

    final lock = shouldLockOnResume(
      enabled: current.enabled,
      backgroundedAt: since,
      now: now,
    );
    if (lock && !current.locked) {
      state = AsyncData(current.copyWith(locked: true));
    }
  }

  Future<AuthOutcome> unlock() async {
    final current = state.value;
    if (current == null || !current.locked || _authenticating) {
      return AuthOutcome.failed;
    }

    final outcome = await _authenticate('Unlock Spendly');
    final latest = state.value ?? current;
    state = AsyncData(
      outcome == AuthOutcome.success
          ? latest.copyWith(locked: false, unavailable: false)
          : latest.copyWith(unavailable: outcome == AuthOutcome.unavailable),
    );
    return outcome;
  }

  /// Turning the lock on asks the user to authenticate first, which also
  /// proves the phone has a screen lock, so they cannot lock themselves out.
  Future<LockChange> enable() async {
    if (!await _auth.isSupported()) return LockChange.unsupported;

    final outcome = await _authenticate("Confirm it's you to turn on app lock");
    if (outcome != AuthOutcome.success) return LockChange.failed;

    await _store.setEnabled(true);
    state = const AsyncData(AppLockState(enabled: true, locked: false));
    return LockChange.done;
  }

  Future<LockChange> disable() async {
    final outcome =
        await _authenticate("Confirm it's you to turn off app lock");

    // "unavailable" means the phone has no screen lock any more, so nobody
    // can be verified. Let the user switch the lock off instead of trapping them.
    if (outcome == AuthOutcome.failed) return LockChange.failed;

    await _store.setEnabled(false);
    state = const AsyncData(AppLockState(enabled: false, locked: false));
    return LockChange.done;
  }

  Future<AuthOutcome> _authenticate(String reason) async {
    _authenticating = true;
    try {
      return await _auth.authenticate(reason);
    } finally {
      _authenticating = false;
      _backgroundedAt = null;
    }
  }
}

final appLockProvider =
    AsyncNotifierProvider<AppLockController, AppLockState>(
  AppLockController.new,
);