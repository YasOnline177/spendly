import 'package:flutter_test/flutter_test.dart';
import 'package:spendly_android/data/models/transaction.dart';
import 'package:spendly_android/features/reports/application/report_calculations.dart';

AppTransaction _tx(
  double amount,
  TransactionType type,
  String category,
  DateTime date,
) {
  return AppTransaction(
    id: 1,
    amount: amount,
    type: type,
    category: category,
    note: '',
    date: date,
  );
}

void main() {
  final oct = DateTime(2026, 10, 10);
  final sep = DateTime(2026, 9, 10);

  test('expenseByCategory sums expenses of the given month only', () {
    final txs = [
      _tx(500, TransactionType.expense, 'Food', oct),
      _tx(300, TransactionType.expense, 'Food', oct),
      _tx(200, TransactionType.expense, 'Bills', oct),
      _tx(900, TransactionType.expense, 'Food', sep),
      _tx(5000, TransactionType.income, 'Salary', oct),
    ];

    final result = expenseByCategory(txs, DateTime(2026, 10));

    expect(result, {'Food': 800, 'Bills': 200});
  });

  test('lastMonths returns 6 months oldest first, across a year boundary', () {
    final result = lastMonths([], DateTime(2026, 2), count: 6);

    expect(result.length, 6);
    expect(result.first.month, DateTime(2025, 9));
    expect(result.last.month, DateTime(2026, 2));
  });

  test('lastMonths totals income and expense per month', () {
    final txs = [
      _tx(1000, TransactionType.income, 'Salary', oct),
      _tx(400, TransactionType.expense, 'Food', oct),
      _tx(250, TransactionType.expense, 'Food', sep),
    ];

    final result = lastMonths(txs, DateTime(2026, 10));

    expect(result.last.income, 1000);
    expect(result.last.expense, 400);
    expect(result[result.length - 2].expense, 250);
  });
}