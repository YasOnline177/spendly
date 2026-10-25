import 'package:flutter_test/flutter_test.dart';
import 'package:spendly_android/data/models/budget.dart';
import 'package:spendly_android/data/models/transaction.dart';
import 'package:spendly_android/features/budgets/application/budget_calculations.dart';

AppTransaction _expense(double amount, String category, DateTime date) {
  return AppTransaction(
    id: 1,
    amount: amount,
    type: TransactionType.expense,
    category: category,
    note: '',
    date: date,
  );
}

void main() {
  final oct = DateTime(2026, 10, 10);
  final sep = DateTime(2026, 9, 10);
  final month = DateTime(2026, 10);

  test('spent only counts expenses of that category and month', () {
    final budgets = [const Budget(category: 'Food', limit: 10000)];
    final txs = [
      _expense(2000, 'Food', oct),
      _expense(1000, 'Food', oct),
      _expense(5000, 'Food', sep),
      _expense(700, 'Bills', oct),
    ];

    final result = budgetProgress(budgets, txs, month);

    expect(result.single.spent, 3000);
    expect(result.single.ratio, closeTo(0.3, 0.0001));
    expect(result.single.remaining, 7000);
    expect(result.single.isOver, isFalse);
  });

  test('flags a budget as over when spending exceeds the limit', () {
    final budgets = [const Budget(category: 'Food', limit: 1000)];
    final txs = [_expense(1500, 'Food', oct)];

    final result = budgetProgress(budgets, txs, month);

    expect(result.single.isOver, isTrue);
    expect(result.single.remaining, -500);
  });

  test('sorts most-used budgets first and handles no spending', () {
    final budgets = [
      const Budget(category: 'Transport', limit: 5000),
      const Budget(category: 'Food', limit: 1000),
    ];
    final txs = [_expense(900, 'Food', oct)];

    final result = budgetProgress(budgets, txs, month);

    expect(result.first.budget.category, 'Food');
    expect(result.last.spent, 0);
  });
}