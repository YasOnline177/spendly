import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/transaction.dart';
import 'transaction_repository.dart';

class DriftTransactionRepository implements TransactionRepository {
  DriftTransactionRepository(this._db, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;
  static const _uuid = Uuid();

  int get _stamp => _now().millisecondsSinceEpoch;

  @override
  Future<List<AppTransaction>> getAll() async {
    final query = _db.select(_db.transactions)
      ..where((t) => t.deleted.equals(false))
      ..orderBy([
        (t) => OrderingTerm.desc(t.date),
        (t) => OrderingTerm.desc(t.id),
      ]);
    final rows = await query.get();
    return rows.map(_toModel).toList();
  }

  /// id 0 inserts a new row. A real id updates that row (edit, or undo of a
  /// delete) and keeps its sync id.
  @override
  Future<void> add(AppTransaction t) async {
    if (t.id == 0) {
      await _db.into(_db.transactions).insert(
            TransactionsCompanion.insert(
              amount: t.amount,
              type: t.type.name,
              category: t.category,
              note: Value(t.note),
              date: t.date,
              syncId: Value(_uuid.v4()),
              updatedAt: Value(_stamp),
              dirty: const Value(true),
            ),
          );
      return;
    }

    await (_db.update(_db.transactions)..where((r) => r.id.equals(t.id))).write(
      TransactionsCompanion(
        amount: Value(t.amount),
        type: Value(t.type.name),
        category: Value(t.category),
        note: Value(t.note),
        date: Value(t.date),
        deleted: const Value(false),
        dirty: const Value(true),
        updatedAt: Value(_stamp),
      ),
    );
  }

  /// Soft delete: the row stays so the deletion can be synced.
  @override
  Future<void> remove(int id) async {
    await (_db.update(_db.transactions)..where((r) => r.id.equals(id))).write(
      TransactionsCompanion(
        deleted: const Value(true),
        dirty: const Value(true),
        updatedAt: Value(_stamp),
      ),
    );
  }

  AppTransaction _toModel(TransactionRow r) => AppTransaction(
        id: r.id,
        amount: r.amount,
        type: TransactionType.values.byName(r.type),
        category: r.category,
        note: r.note,
        date: r.date,
      );
}