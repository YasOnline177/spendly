import '../../../core/utils/formatters.dart';
import '../../budgets/application/budget_calculations.dart';

enum AlertLevel { warning, reached }

class BudgetAlert {
  const BudgetAlert({
    required this.category,
    required this.level,
    required this.spent,
    required this.limit,
    required this.keys,
  });

  final String category;
  final AlertLevel level;
  final double spent;
  final double limit;

  /// Marked as "sent" once the notification is actually delivered.
  final Set<String> keys;

  /// The same category and level always reuse one id, so a newer alert
  /// replaces last month's instead of piling up.
  int get notificationId => '$category|${level.name}'.hashCode & 0x7fffffff;
}

String monthPrefix(DateTime month) =>
    '${month.year}-${month.month.toString().padLeft(2, '0')}|';

String alertKey(DateTime month, String category, AlertLevel level) =>
    '${monthPrefix(month)}$category|${level.name}';

// Money is compared in whole cents so floating-point sums can't flip a result.
int _cents(double value) => (value * 100).round();

/// Which alerts should be sent now.
///
/// - 80% sends a warning, 100% sends "limit reached".
/// - Jumping straight past 100% sends only the "reached" alert.
/// - Nothing is sent twice in the same month, even if spending goes down
///   and up again.
List<BudgetAlert> planAlerts({
  required List<BudgetProgress> progress,
  required Set<String> alreadySent,
  required DateTime month,
  double warningAt = 0.8,
}) {
  final alerts = <BudgetAlert>[];

  for (final p in progress) {
    final limit = _cents(p.budget.limit);
    if (limit <= 0) continue;

    final spent = _cents(p.spent);
    final category = p.budget.category;
    final warningKey = alertKey(month, category, AlertLevel.warning);
    final reachedKey = alertKey(month, category, AlertLevel.reached);

    if (spent >= limit) {
      if (!alreadySent.contains(reachedKey)) {
        alerts.add(
          BudgetAlert(
            category: category,
            level: AlertLevel.reached,
            spent: p.spent,
            limit: p.budget.limit,
            // Reaching 100% also uses up the 80% warning for this month.
            keys: {warningKey, reachedKey},
          ),
        );
      }
    } else if (spent >= (limit * warningAt).round()) {
      if (!alreadySent.contains(warningKey)) {
        alerts.add(
          BudgetAlert(
            category: category,
            level: AlertLevel.warning,
            spent: p.spent,
            limit: p.budget.limit,
            keys: {warningKey},
          ),
        );
      }
    }
  }
  return alerts;
}

({String title, String body}) alertMessage(BudgetAlert alert) {
  final body =
      '${currencyFmt.format(alert.spent)} of ${currencyFmt.format(alert.limit)} spent this month.';

  switch (alert.level) {
    case AlertLevel.warning:
      final percent = _cents(alert.spent) * 100 ~/ _cents(alert.limit);
      return (title: '${alert.category} budget: $percent% used', body: body);
    case AlertLevel.reached:
      return (title: '${alert.category} budget limit reached', body: body);
  }
}