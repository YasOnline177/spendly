import 'package:flutter_test/flutter_test.dart';
import 'package:spendly_android/data/recurring/recurrence.dart';

void main() {
  group('occurrencesUpTo', () {
    test('weekly: every 7 days, including the last day', () {
      final r = occurrencesUpTo(
        Frequency.weekly,
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 22),
      );
      expect(r, [
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 8),
        DateTime(2026, 10, 15),
        DateTime(2026, 10, 22),
      ]);
    });

    test('monthly: same day each month, across a year boundary', () {
      final r = occurrencesUpTo(
        Frequency.monthly,
        DateTime(2026, 11, 15),
        DateTime(2027, 2, 20),
      );
      expect(r, [
        DateTime(2026, 11, 15),
        DateTime(2026, 12, 15),
        DateTime(2027, 1, 15),
        DateTime(2027, 2, 15),
      ]);
    });

    test('monthly on the 31st uses the last day of short months, no drift', () {
      final r = occurrencesUpTo(
        Frequency.monthly,
        DateTime(2026, 1, 31),
        DateTime(2026, 5, 31),
      );
      expect(r, [
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 31), // back to the 31st, not stuck on the 28th
        DateTime(2026, 4, 30),
        DateTime(2026, 5, 31),
      ]);
    });

    test('leap year: the 31st lands on February 29', () {
      final r = occurrencesUpTo(
        Frequency.monthly,
        DateTime(2028, 1, 31),
        DateTime(2028, 3, 1),
      );
      expect(r, [DateTime(2028, 1, 31), DateTime(2028, 2, 29)]);
    });

    test('nothing happens before the start date', () {
      final r = occurrencesUpTo(
        Frequency.monthly,
        DateTime(2026, 12, 1),
        DateTime(2026, 11, 16),
      );
      expect(r, isEmpty);
    });

    test('time of day is ignored on both ends', () {
      final r = occurrencesUpTo(
        Frequency.weekly,
        DateTime(2026, 10, 1, 18, 45),
        DateTime(2026, 10, 8, 0, 5),
      );
      expect(r, [DateTime(2026, 10, 1), DateTime(2026, 10, 8)]);
    });

    test('stops at maxCount', () {
      final r = occurrencesUpTo(
        Frequency.weekly,
        DateTime(2020, 1, 1),
        DateTime(2026, 12, 31),
        maxCount: 5,
      );
      expect(r, hasLength(5));
    });
  });

  group('nextOccurrence', () {
    test('returns the first occurrence strictly after the given date', () {
      final start = DateTime(2026, 1, 31);
      expect(
        nextOccurrence(Frequency.monthly, start, DateTime(2026, 2, 28)),
        DateTime(2026, 3, 31),
      );
      expect(
        nextOccurrence(Frequency.monthly, start, DateTime(2026, 3, 30)),
        DateTime(2026, 3, 31),
      );
    });

    test('returns the start date when it is still in the future', () {
      expect(
        nextOccurrence(
          Frequency.weekly,
          DateTime(2026, 12, 1),
          DateTime(2026, 11, 16),
        ),
        DateTime(2026, 12, 1),
      );
    });
  });

  test('occurrenceSyncId is the rule id plus the date', () {
    expect(occurrenceSyncId('abc', DateTime(2026, 3, 7)), 'abc:20260307');
  });
}