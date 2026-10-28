import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../models/budget.dart';
import 'budget_repository.dart';

class DriftBudgetRepository implements BudgetRepository {
  DriftBudgetRepository(this._db, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  int get _stamp => _now().millisecondsSinceEpoch;

  @override
  Future<List<Budget>> getAll() async {
    final query = _db.select(_db.budgets)
      ..where((b) => b.deleted.equals(false));
    final rows = await query.get();
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
            updatedAt: Value(_stamp),
            deleted: const Value(false),
            dirty: const Value(true),
          ),
        );
  }

  @override
  Future<void> remove(String category) async {
    await (_db.update(_db.budgets)..where((b) => b.category.equals(category)))
        .write(
      BudgetsCompanion(
        deleted: const Value(true),
        dirty: const Value(true),
        updatedAt: Value(_stamp),
      ),
    );
  }
}