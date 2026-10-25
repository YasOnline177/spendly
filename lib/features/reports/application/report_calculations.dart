import '../../../data/models/transaction.dart';

class MonthTotal {
  final DateTime month;
  final double income;
  final double expense;
  const MonthTotal({
    required this.month,
    required this.income,
    required this.expense,
  });
}

bool _sameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

/// Total expense per category for the given month.
Map<String, double> expenseByCategory(
  List<AppTransaction> txs,
  DateTime month,
) {
  final result = <String, double>{};
  for (final t in txs) {
    if (t.type == TransactionType.expense && _sameMonth(t.date, month)) {
      result[t.category] = (result[t.category] ?? 0) + t.amount;
    }
  }
  return result;
}

/// Income and expense totals for the last [count] months, oldest first.
List<MonthTotal> lastMonths(
  List<AppTransaction> txs,
  DateTime now, {
  int count = 6,
}) {
  final months = List.generate(
    count,
    (i) => DateTime(now.year, now.month - (count - 1 - i)),
  );

  return months.map((m) {
    double income = 0;
    double expense = 0;
    for (final t in txs) {
      if (!_sameMonth(t.date, m)) continue;
      if (t.type == TransactionType.income) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    return MonthTotal(month: m, income: income, expense: expense);
  }).toList();
}