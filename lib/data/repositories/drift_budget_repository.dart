import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../models/budget.dart';
import 'budget_repository.dart';

class DriftBudgetRepository implements BudgetRepository {
  DriftBudgetRepository(this._db);
  final AppDatabase _db;

  @override
  Future<List<Budget>> getAll() async {
    final rows = await _db.select(_db.budgets).get();
    return rows
        .map((r) => Budget(category: r.category, limit: r.monthlyLimit))
        .toList();
  }

  @override
  Future<void> upsert(Budget budget) async {
    await _db.into(_db.budgets).insertOnConflictUpdate(
          BudgetsCompanion.insert(
            category: budget.category,
            monthlyLimit: budget.limit,
          ),
        );
  }

  @override
  Future<void> remove(String category) async {
    await (_db.delete(_db.budgets)..where((b) => b.category.equals(category)))
        .go();
  }
}