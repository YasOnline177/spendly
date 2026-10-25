import '../../../data/models/budget.dart';
import '../../../data/models/transaction.dart';
import '../../reports/application/report_calculations.dart';

class BudgetProgress {
  final Budget budget;
  final double spent;

  const BudgetProgress({required this.budget, required this.spent});

  double get ratio => budget.limit == 0 ? 0 : spent / budget.limit;
  double get remaining => budget.limit - spent;
  bool get isOver => spent > budget.limit;
}

/// Progress of every budget for [month], most-used budget first.
List<BudgetProgress> budgetProgress(
  List<Budget> budgets,
  List<AppTransaction> txs,
  DateTime month,
) {
  final spentByCategory = expenseByCategory(txs, month);

  final list = budgets
      .map((b) => BudgetProgress(
            budget: b,
            spent: spentByCategory[b.category] ?? 0,
          ))
      .toList();

  list.sort((a, b) => b.ratio.compareTo(a.ratio));
  return list;
}