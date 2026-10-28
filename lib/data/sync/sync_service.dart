import 'package:drift/drift.dart';
import '../database/app_database.dart';
import 'remote_store.dart';

/// Two-way sync between the local database and the cloud.
///
/// Rule: for the same item, the version with the newer `updatedAt` wins.
/// Pull happens before push so an offline device fails fast, before it
/// queues any cloud writes.
class SyncService {
  SyncService(this._db, this._remote);

  final AppDatabase _db;
  final RemoteStore _remote;

  Future<void> sync() async {
    await _pullTransactions();
    await _pullBudgets();
    await _pushTransactions();
    await _pushBudgets();
  }

  // ---------------------------------------------------------------- pull

  Future<void> _pullTransactions() async {
    final remote = await _remote.fetchTransactions();

    for (final r in remote) {
      final local = await (_db.select(_db.transactions)
            ..where((t) => t.syncId.equals(r.syncId)))
          .getSingleOrNull();

      if (local == null) {
        if (r.deleted) continue; // nothing to delete, nothing to create
        await _db.into(_db.transactions).insert(
              TransactionsCompanion.insert(
                amount: r.amount,
                type: r.type,
                category: r.category,
                note: Value(r.note),
                date: DateTime.fromMillisecondsSinceEpoch(r.date),
                syncId: Value(r.syncId),
                updatedAt: Value(r.updatedAt),
                deleted: const Value(false),
                dirty: const Value(false),
              ),
            );
      } else if (r.updatedAt > local.updatedAt) {
        await (_db.update(_db.transactions)
              ..where((t) => t.id.equals(local.id)))
            .write(
          TransactionsCompanion(
            amount: Value(r.amount),
            type: Value(r.type),
            category: Value(r.category),
            note: Value(r.note),
            date: Value(DateTime.fromMillisecondsSinceEpoch(r.date)),
            updatedAt: Value(r.updatedAt),
            deleted: Value(r.deleted),
            dirty: const Value(false),
          ),
        );
      }
      // Local is newer or equal: keep it. If dirty, it is pushed below.
    }
  }

  Future<void> _pullBudgets() async {
    final remote = await _remote.fetchBudgets();

    for (final r in remote) {
      final local = await (_db.select(_db.budgets)
            ..where((b) => b.category.equals(r.category)))
          .getSingleOrNull();

      if (local == null) {
        if (r.deleted) continue;
        await _db.into(_db.budgets).insert(
              BudgetsCompanion.insert(
                category: r.category,
                monthlyLimit: r.monthlyLimit,
                updatedAt: Value(r.updatedAt),
                deleted: const Value(false),
                dirty: const Value(false),
              ),
            );
      } else if (r.updatedAt > local.updatedAt) {
        await (_db.update(_db.budgets)
              ..where((b) => b.category.equals(r.category)))
            .write(
          BudgetsCompanion(
            monthlyLimit: Value(r.monthlyLimit),
            updatedAt: Value(r.updatedAt),
            deleted: Value(r.deleted),
            dirty: const Value(false),
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------- push

  Future<void> _pushTransactions() async {
    final dirty = await (_db.select(_db.transactions)
          ..where((t) => t.dirty.equals(true) & t.syncId.isNotNull()))
        .get();
    if (dirty.isEmpty) return;

    await _remote.pushTransactions(
      dirty
          .map(
            (r) => RemoteTransaction(
              syncId: r.syncId!,
              amount: r.amount,
              type: r.type,
              category: r.category,
              note: r.note,
              date: r.date.millisecondsSinceEpoch,
              updatedAt: r.updatedAt,
              deleted: r.deleted,
            ),
          )
          .toList(),
    );

    // Mark clean only if the row was not edited again while we were uploading.
    for (final r in dirty) {
      await (_db.update(_db.transactions)
            ..where((t) => t.id.equals(r.id) & t.updatedAt.equals(r.updatedAt)))
          .write(const TransactionsCompanion(dirty: Value(false)));
    }
  }

  Future<void> _pushBudgets() async {
    final dirty = await (_db.select(_db.budgets)
          ..where((b) => b.dirty.equals(true)))
        .get();
    if (dirty.isEmpty) return;

    await _remote.pushBudgets(
      dirty
          .map(
            (r) => RemoteBudget(
              category: r.category,
              monthlyLimit: r.monthlyLimit,
              updatedAt: r.updatedAt,
              deleted: r.deleted,
            ),
          )
          .toList(),
    );

    for (final r in dirty) {
      await (_db.update(_db.budgets)
            ..where(
              (b) =>
                  b.category.equals(r.category) &
                  b.updatedAt.equals(r.updatedAt),
            ))
          .write(const BudgetsCompanion(dirty: Value(false)));
    }
  }
}