import 'package:flutter_test/flutter_test.dart';
import 'package:spendly_android/features/lock/application/lock_rules.dart';

void main() {
  final left = DateTime(2026, 11, 28, 12);

  bool lockAfter(Duration away, {bool enabled = true, DateTime? since}) {
    return shouldLockOnResume(
      enabled: enabled,
      backgroundedAt: since ?? left,
      now: left.add(away),
    );
  }

  test('does not lock after a quick app switch', () {
    expect(lockAfter(const Duration(seconds: 10)), isFalse);
  });

  test('does not lock at exactly the grace period', () {
    expect(lockAfter(lockGracePeriod), isFalse);
  });

  test('locks after more than the grace period', () {
    expect(lockAfter(const Duration(seconds: 31)), isTrue);
  });

  test('never locks when app lock is off', () {
    expect(lockAfter(const Duration(hours: 5), enabled: false), isFalse);
  });

  test('does not lock if the app was never in the background', () {
    final result = shouldLockOnResume(
      enabled: true,
      backgroundedAt: null,
      now: left,
    );
    expect(result, isFalse);
  });

  test('does not lock if the clock moved backwards', () {
    expect(lockAfter(const Duration(seconds: -60)), isFalse);
  });

  test('a custom grace period is respected', () {
    final result = shouldLockOnResume(
      enabled: true,
      backgroundedAt: left,
      now: left.add(const Duration(minutes: 2)),
      grace: const Duration(minutes: 5),
    );
    expect(result, isFalse);
  });
}