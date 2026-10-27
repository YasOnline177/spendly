import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/budget.dart';
import '../../../data/repositories/budget_repository.dart';
import '../../../data/repositories/drift_budget_repository.dart';
import '../../transactions/application/transactions_provider.dart';
import 'budget_calculations.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => DriftBudgetRepository(ref.watch(databaseProvider)),
);

class BudgetsNotifier extends Notifier<List<Budget>> {
  BudgetRepository get _repo => ref.read(budgetRepositoryProvider);

  @override
  List<Budget> build() {
    ref.watch(budgetRepositoryProvider);
    _load();
    return [];
  }

  Future<void> _load() async {
    state = await _repo.getAll();
  }

  Future<void> upsert(Budget budget) async {
    await _repo.upsert(budget);
    await _load();
  }

  Future<void> remove(String category) async {
    state = state.where((b) => b.category != category).toList();
    await _repo.remove(category);
  }
}

final budgetsProvider = NotifierProvider<BudgetsNotifier, List<Budget>>(
  BudgetsNotifier.new,
);

final budgetProgressProvider = Provider<List<BudgetProgress>>((ref) {
  final budgets = ref.watch(budgetsProvider);
  final txs = ref.watch(transactionsProvider).value ?? [];
  final now = DateTime.now();
  return budgetProgress(budgets, txs, DateTime(now.year, now.month));
});