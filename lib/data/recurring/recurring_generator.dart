import 'package:drift/drift.dart';
import '../database/app_database.dart';
import 'recurrence.dart';

/// Creates the transactions that recurring rules say are due.
///
/// Safe to run as often as you like: an occurrence that already exists
/// (even one the user deleted) is never created again.
class RecurringGenerator {
  RecurringGenerator(this._db);

  final AppDatabase _db;

  /// Returns how many transactions were created.
  Future<int> generateDue(DateTime now) async {
    final rules = await (_db.select(_db.recurringRules)
          ..where((r) => r.deleted.equals(false)))
        .get();

    var created = 0;
    for (final rule in rules) {
      final dates = occurrencesUpTo(
        Frequency.values.byName(rule.frequency),
        rule.startDate,
        now,
      );
      if (dates.isEmpty) continue;

      // Soft-deleted rows are included on purpose, so deleted ones stay gone.
      final existing = (await (_db.select(_db.transactions)
                ..where((t) => t.syncId.like('${rule.syncId}:%')))
              .get())
          .map((t) => t.syncId)
          .toSet();

      for (final date in dates) {
        final syncId = occurrenceSyncId(rule.syncId, date);
        if (existing.contains(syncId)) continue;

        await _db.into(_db.transactions).insert(
              TransactionsCompanion.insert(
                amount: rule.amount,
                type: rule.type,
                category: rule.category,
                note: Value(rule.note),
                date: date,
                syncId: Value(syncId),
                // The occurrence date, not "now": any later edit or delete by
                // the user has a newer timestamp, so it wins when syncing.
                updatedAt: Value(date.millisecondsSinceEpoch),
                deleted: const Value(false),
                dirty: const Value(true),
              ),
            );
        created++;
      }
    }
    return created;
  }
}