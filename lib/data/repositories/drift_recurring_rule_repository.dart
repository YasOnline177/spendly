import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../models/recurring_rule.dart';
import '../models/transaction.dart';
import '../recurring/recurrence.dart';
import 'recurring_rule_repository.dart';

class DriftRecurringRuleRepository implements RecurringRuleRepository {
  DriftRecurringRuleRepository(this._db, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  int get _stamp => _now().millisecondsSinceEpoch;

  @override
  Future<List<RecurringRule>> getAll() async {
    final query = _db.select(_db.recurringRules)
      ..where((r) => r.deleted.equals(false))
      ..orderBy([
        (r) => OrderingTerm.asc(r.category),
        (r) => OrderingTerm.asc(r.startDate),
      ]);
    final rows = await query.get();
    return rows.map(_toModel).toList();
  }

  @override
  Future<void> add(RecurringRule rule) async {
    await _db.into(_db.recurringRules).insertOnConflictUpdate(
          RecurringRulesCompanion.insert(
            syncId: rule.syncId,
            amount: rule.amount,
            type: rule.type.name,
            category: rule.category,
            note: Value(rule.note),
            frequency: rule.frequency.name,
            startDate: rule.startDate,
            updatedAt: Value(_stamp),
            deleted: const Value(false),
            dirty: const Value(true),
          ),
        );
  }

  /// Soft delete, so the deletion can be synced.
  @override
  Future<void> remove(String syncId) async {
    await (_db.update(_db.recurringRules)
          ..where((r) => r.syncId.equals(syncId)))
        .write(
      RecurringRulesCompanion(
        deleted: const Value(true),
        dirty: const Value(true),
        updatedAt: Value(_stamp),
      ),
    );
  }

  RecurringRule _toModel(RecurringRuleRow r) => RecurringRule(
        syncId: r.syncId,
        amount: r.amount,
        type: TransactionType.values.byName(r.type),
        category: r.category,
        note: r.note,
        frequency: Frequency.values.byName(r.frequency),
        startDate: r.startDate,
      );
}