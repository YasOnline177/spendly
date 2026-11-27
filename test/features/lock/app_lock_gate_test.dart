import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly_android/data/models/app_user.dart';
import 'package:spendly_android/features/auth/application/auth_provider.dart';
import 'package:spendly_android/features/lock/application/app_lock_provider.dart';
import 'package:spendly_android/features/lock/data/biometric_authenticator.dart';
import 'package:spendly_android/features/lock/presentation/app_lock_gate.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_lock.dart';

const _verified = AppUser(uid: 'u1', email: 'me@example.com', emailVerified: true);

Widget _app({
  required FakeAppLockStore store,
  required FakeBiometricAuthenticator authenticator,
  AppUser? user = _verified,
}) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(FakeAuthRepository(user: user)),
      appLockStoreProvider.overrideWithValue(store),
      biometricAuthenticatorProvider.overrideWithValue(authenticator),
    ],
    child: MaterialApp(
      builder: (context, child) => AppLockGate(child: child!),
      home: const Scaffold(body: Text('secret')),
    ),
  );
}

void main() {
  testWidgets('hides the app behind a lock screen until unlocked',
      (tester) async {
    final authenticator = FakeBiometricAuthenticator()
      ..outcome = AuthOutcome.failed;

    await tester.pumpWidget(
      _app(store: FakeAppLockStore(enabled: true), authenticator: authenticator),
    );
    await tester.pumpAndSettle();

    expect(find.text('Spendly is locked'), findsOneWidget);
    expect(find.text('secret'), findsNothing);
    expect(authenticator.calls, 1); // asked for the fingerprint automatically

    authenticator.outcome = AuthOutcome.success;
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(find.text('secret'), findsOneWidget);
    expect(find.text('Spendly is locked'), findsNothing);
  });

  testWidgets('does not lock when app lock is off', (tester) async {
    await tester.pumpWidget(
      _app(
        store: FakeAppLockStore(),
        authenticator: FakeBiometricAuthenticator(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('secret'), findsOneWidget);
    expect(find.text('Spendly is locked'), findsNothing);
  });

  testWidgets('never locks the sign-in screen', (tester) async {
    final authenticator = FakeBiometricAuthenticator();

    await tester.pumpWidget(
      _app(
        store: FakeAppLockStore(enabled: true),
        authenticator: authenticator,
        user: null,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('secret'), findsOneWidget);
    expect(authenticator.calls, 0);
  });

  testWidgets('offers to turn the lock off when the phone cannot verify you',
      (tester) async {
    final authenticator = FakeBiometricAuthenticator()
      ..outcome = AuthOutcome.unavailable;
    final store = FakeAppLockStore(enabled: true);

    await tester.pumpWidget(_app(store: store, authenticator: authenticator));
    await tester.pumpAndSettle();

    expect(find.text('Turn off app lock'), findsOneWidget);

    await tester.tap(find.text('Turn off app lock'));
    await tester.pumpAndSettle();

    expect(store.enabled, isFalse);
    expect(find.text('secret'), findsOneWidget);
  });
}