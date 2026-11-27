import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly_android/data/models/app_user.dart';
import 'package:spendly_android/features/auth/application/auth_provider.dart';
import 'package:spendly_android/features/lock/application/app_lock_provider.dart';
import 'package:spendly_android/features/lock/data/biometric_authenticator.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_lock.dart';

const _verified = AppUser(
  uid: 'u1',
  email: 'me@example.com',
  emailVerified: true,
);
const _unverified = AppUser(uid: 'u1', email: 'me@example.com');

void main() {
  late FakeAppLockStore store;
  late FakeBiometricAuthenticator authenticator;
  final t0 = DateTime(2026, 11, 28, 12);

  setUp(() {
    store = FakeAppLockStore(enabled: true);
    authenticator = FakeBiometricAuthenticator();
  });

  Future<ProviderContainer> open({AppUser? user = _verified}) async {
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWithValue(AsyncData<AppUser?>(user)),
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(user: user),
        ),
        appLockStoreProvider.overrideWithValue(store),
        biometricAuthenticatorProvider.overrideWithValue(authenticator),
      ],
    );

    addTearDown(container.dispose);

    for (var i = 0;
        i < 100 && container.read(authStateProvider).isLoading;
        i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    await container.read(appLockProvider.future);

    return container;
  }

  AppLockState stateOf(ProviderContainer c) => c.read(appLockProvider).value!;

  group('cold start', () {
    test(
      'is locked when app lock is on and a verified user is signed in',
      () async {
        final c = await open();
        expect(stateOf(c).locked, isTrue);
      },
    );

    test('is unlocked when app lock is off', () async {
      store.enabled = false;
      final c = await open();
      expect(stateOf(c).locked, isFalse);
    });

    test('is unlocked when nobody is signed in', () async {
      final c = await open(user: null);
      expect(stateOf(c).locked, isFalse);
    });

    test('is unlocked for a user who has not verified their email', () async {
      final c = await open(user: _unverified);
      expect(stateOf(c).locked, isFalse);
    });
  });

  group('unlock', () {
    test('success unlocks', () async {
      final c = await open();

      final outcome = await c.read(appLockProvider.notifier).unlock();

      expect(outcome, AuthOutcome.success);
      expect(stateOf(c).locked, isFalse);
    });

    test('a failed attempt stays locked', () async {
      authenticator.outcome = AuthOutcome.failed;
      final c = await open();

      await c.read(appLockProvider.notifier).unlock();

      expect(stateOf(c).locked, isTrue);
      expect(stateOf(c).unavailable, isFalse);
    });

    test('flags when the phone cannot verify the user', () async {
      authenticator.outcome = AuthOutcome.unavailable;
      final c = await open();

      await c.read(appLockProvider.notifier).unlock();

      expect(stateOf(c).locked, isTrue);
      expect(stateOf(c).unavailable, isTrue);
    });

    test('a second request while a prompt is open is ignored', () async {
      authenticator.hold = Completer<void>();
      final c = await open();
      final notifier = c.read(appLockProvider.notifier);

      final first = notifier.unlock();
      final second = notifier.unlock();
      authenticator.hold!.complete();
      await Future.wait([first, second]);

      expect(authenticator.calls, 1);
    });

    test('clearLock unlocks without a prompt', () async {
      final c = await open();

      c.read(appLockProvider.notifier).clearLock();

      expect(stateOf(c).locked, isFalse);
      expect(authenticator.calls, 0);
    });
  });

  group('returning from the background', () {
    Future<ProviderContainer> openUnlocked() async {
      final c = await open();
      await c.read(appLockProvider.notifier).unlock();
      return c;
    }

    test('a quick return does not lock', () async {
      final c = await openUnlocked();
      final notifier = c.read(appLockProvider.notifier);

      notifier.onBackgrounded(t0);
      notifier.onResumed(t0.add(const Duration(seconds: 10)), signedIn: true);

      expect(stateOf(c).locked, isFalse);
    });

    test('returning after more than 30 seconds locks', () async {
      final c = await openUnlocked();
      final notifier = c.read(appLockProvider.notifier);

      notifier.onBackgrounded(t0);
      notifier.onResumed(t0.add(const Duration(seconds: 31)), signedIn: true);

      expect(stateOf(c).locked, isTrue);
    });

    test('does not lock when nobody is signed in', () async {
      final c = await openUnlocked();
      final notifier = c.read(appLockProvider.notifier);

      notifier.onBackgrounded(t0);
      notifier.onResumed(t0.add(const Duration(minutes: 5)), signedIn: false);

      expect(stateOf(c).locked, isFalse);
    });

    test('does not lock when app lock is off', () async {
      store.enabled = false;
      final c = await open();
      final notifier = c.read(appLockProvider.notifier);

      notifier.onBackgrounded(t0);
      notifier.onResumed(t0.add(const Duration(minutes: 5)), signedIn: true);

      expect(stateOf(c).locked, isFalse);
    });

    test('app pauses caused by the prompt itself are ignored', () async {
      authenticator.hold = Completer<void>();
      final c = await open();
      final notifier = c.read(appLockProvider.notifier);

      final unlocking = notifier.unlock();
      notifier.onBackgrounded(t0); // the prompt paused the app
      authenticator.hold!.complete();
      await unlocking;

      // The user took a minute to type their PIN.
      notifier.onResumed(t0.add(const Duration(minutes: 1)), signedIn: true);

      expect(stateOf(c).locked, isFalse);
    });
  });

  group('turning app lock on', () {
    setUp(() => store.enabled = false);

    test('is refused when the phone has no screen lock', () async {
      authenticator.supported = false;
      final c = await open();

      final result = await c.read(appLockProvider.notifier).enable();

      expect(result, LockChange.unsupported);
      expect(store.enabled, isFalse);
      expect(authenticator.calls, 0);
    });

    test('needs the user to authenticate first', () async {
      authenticator.outcome = AuthOutcome.failed;
      final c = await open();

      final result = await c.read(appLockProvider.notifier).enable();

      expect(result, LockChange.failed);
      expect(store.enabled, isFalse);
    });

    test('turns on and stays unlocked for this session', () async {
      final c = await open();

      final result = await c.read(appLockProvider.notifier).enable();

      expect(result, LockChange.done);
      expect(store.enabled, isTrue);
      expect(stateOf(c).enabled, isTrue);
      expect(stateOf(c).locked, isFalse);
    });
  });

  group('turning app lock off', () {
    test('needs the user to authenticate first', () async {
      authenticator.outcome = AuthOutcome.failed;
      final c = await open();
      c.read(appLockProvider.notifier).clearLock();

      final result = await c.read(appLockProvider.notifier).disable();

      expect(result, LockChange.failed);
      expect(store.enabled, isTrue);
    });

    test('turns off after authenticating', () async {
      final c = await open();

      final result = await c.read(appLockProvider.notifier).disable();

      expect(result, LockChange.done);
      expect(store.enabled, isFalse);
      expect(stateOf(c).enabled, isFalse);
      expect(stateOf(c).locked, isFalse);
    });

    test('can be turned off when the phone has lost its screen lock', () async {
      authenticator.outcome = AuthOutcome.unavailable;
      final c = await open();

      final result = await c.read(appLockProvider.notifier).disable();

      expect(result, LockChange.done);
      expect(store.enabled, isFalse);
    });
  });
}
