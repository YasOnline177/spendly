import 'dart:async';

import 'package:spendly_android/features/lock/data/app_lock_store.dart';
import 'package:spendly_android/features/lock/data/biometric_authenticator.dart';

class FakeAppLockStore implements AppLockStore {
  FakeAppLockStore({this.enabled = false});

  bool enabled;

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<void> setEnabled(bool value) async => enabled = value;
}

class FakeBiometricAuthenticator implements BiometricAuthenticator {
  bool supported = true;
  AuthOutcome outcome = AuthOutcome.success;

  /// When set, authenticate() waits for it, simulating a prompt on screen.
  Completer<void>? hold;

  int calls = 0;
  final reasons = <String>[];

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<AuthOutcome> authenticate(String reason) async {
    calls++;
    reasons.add(reason);
    await hold?.future;
    return outcome;
  }
}