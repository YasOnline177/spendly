import 'package:flutter_test/flutter_test.dart';
import 'package:spendly_android/data/models/budget.dart';
import 'package:spendly_android/features/alerts/application/alert_logic.dart';
import 'package:spendly_android/features/budgets/application/budget_calculations.dart';

BudgetProgress _p(String category, double limit, double spent) {
  return BudgetProgress(
    budget: Budget(category: category, limit: limit),
    spent: spent,
  );
}

final _oct = DateTime(2026, 10);
final _nov = DateTime(2026, 11);

List<BudgetAlert> _plan(
  List<BudgetProgress> progress, {
  Set<String> sent = const {},
  DateTime? month,
}) {
  return planAlerts(
    progress: progress,
    alreadySent: sent,
    month: month ?? _oct,
  );
}

void main() {
  test('alert keys include the month, category and level', () {
    expect(
      alertKey(_oct, 'Food', AlertLevel.warning),
      '2026-10|Food|warning',
    );
  });

  group('planAlerts', () {
    test('sends nothing below 80%', () {
      expect(_plan([_p('Food', 5000, 3999)]), isEmpty);
    });

    test('sends a warning at exactly 80%', () {
      final alerts = _plan([_p('Food', 5000, 4000)]);

      expect(alerts, hasLength(1));
      expect(alerts.single.level, AlertLevel.warning);
      expect(alerts.single.keys, {'2026-10|Food|warning'});
    });

    test('sends a warning between 80% and 100%', () {
      final alerts = _plan([_p('Food', 5000, 4900)]);
      expect(alerts.single.level, AlertLevel.warning);
    });

    test('sends "reached" at exactly 100% and uses up both keys', () {
      final alerts = _plan([_p('Food', 5000, 5000)]);

      expect(alerts.single.level, AlertLevel.reached);
      expect(alerts.single.keys, {
        '2026-10|Food|warning',
        '2026-10|Food|reached',
      });
    });

    test('sends "reached" when over the limit', () {
      final alerts = _plan([_p('Food', 5000, 6200)]);
      expect(alerts.single.level, AlertLevel.reached);
    });

    test('jumping straight past 100% sends a single alert', () {
      final alerts = _plan([_p('Food', 5000, 7000)]);
      expect(alerts, hasLength(1));
    });

    test('does not repeat a warning that was already sent', () {
      final alerts = _plan(
        [_p('Food', 5000, 4500)],
        sent: {'2026-10|Food|warning'},
      );
      expect(alerts, isEmpty);
    });

    test('still sends "reached" after only the warning was sent', () {
      final alerts = _plan(
        [_p('Food', 5000, 5100)],
        sent: {'2026-10|Food|warning'},
      );
      expect(alerts.single.level, AlertLevel.reached);
    });

    test('stays quiet if spending drops back below 100% after "reached"', () {
      final alerts = _plan(
        [_p('Food', 5000, 4500)],
        sent: {'2026-10|Food|warning', '2026-10|Food|reached'},
      );
      expect(alerts, isEmpty);
    });

    test('a new month starts fresh', () {
      final alerts = _plan(
        [_p('Food', 5000, 4500)],
        sent: {'2026-10|Food|warning', '2026-10|Food|reached'},
        month: _nov,
      );
      expect(alerts.single.level, AlertLevel.warning);
      expect(alerts.single.keys, {'2026-11|Food|warning'});
    });

    test('floating-point sums do not break the 100% check', () {
      // 1000.10 + 2000.20 is 3000.3000000000002 in floating point.
      final alerts = _plan([_p('Food', 3000.30, 1000.10 + 2000.20)]);
      expect(alerts.single.level, AlertLevel.reached);
    });

    test('ignores budgets with a zero limit', () {
      expect(_plan([_p('Food', 0, 100)]), isEmpty);
    });

    test('handles several budgets independently', () {
      final alerts = _plan([
        _p('Food', 5000, 4200),
        _p('Bills', 2000, 100),
        _p('Transport', 1000, 1000),
      ]);

      expect(alerts.map((a) => a.category), ['Food', 'Transport']);
    });
  });

  group('alertMessage', () {
    test('warning shows the percentage used', () {
      final alert = _plan([_p('Food', 5000, 4200)]).single;
      final msg = alertMessage(alert);

      expect(msg.title, 'Food budget: 84% used');
      expect(msg.body, 'LKR 4,200.00 of LKR 5,000.00 spent this month.');
    });

    test('percentage is rounded down, never up to 100', () {
      final alert = _plan([_p('Food', 3000, 2999)]).single;
      expect(alertMessage(alert).title, 'Food budget: 99% used');
    });

    test('reached says the limit was reached', () {
      final alert = _plan([_p('Food', 5000, 5200)]).single;
      final msg = alertMessage(alert);

      expect(msg.title, 'Food budget limit reached');
      expect(msg.body, 'LKR 5,200.00 of LKR 5,000.00 spent this month.');
    });
  });
}