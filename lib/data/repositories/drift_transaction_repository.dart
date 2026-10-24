import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../models/transaction.dart';
import 'transaction_repository.dart';

class DriftTransactionRepository implements TransactionRepository {
  DriftTransactionRepository(this._db);
  final AppDatabase _db;

  @override
  Future<List<AppTransaction>> getAll() async {
    final query = _db.select(_db.transactions)
      ..orderBy([
        (t) => OrderingTerm.desc(t.date),
        (t) => OrderingTerm.desc(t.id),
      ]);
    final rows = await query.get();
    return rows.map(_toModel).toList();
  }

  @override
  Future<void> add(AppTransaction t) async {
    await _db.into(_db.transactions).insert(
          TransactionsCompanion.insert(
            // id 0 means "new": let the database assign one.
            // A real id means "restore" (used by Undo).
            id: t.id == 0 ? const Value.absent() : Value(t.id),
            amount: t.amount,
            type: t.type.name,
            category: t.category,
            note: Value(t.note),
            date: t.date,
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  @override
  Future<void> remove(int id) async {
    await (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();
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