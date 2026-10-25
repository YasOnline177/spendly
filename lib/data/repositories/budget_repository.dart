import '../models/budget.dart';

abstract class BudgetRepository {
  Future<List<Budget>> getAll();
  Future<void> upsert(Budget budget);
  Future<void> remove(String category);
}