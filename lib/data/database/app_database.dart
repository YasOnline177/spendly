import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

part 'app_database.g.dart';

@DataClassName('TransactionRow')
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get amount => real()();
  TextColumn get type => text()(); // 'income' or 'expense'
  TextColumn get category => text()();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get date => dateTime()();

  // Sync columns
  TextColumn get syncId => text().nullable()();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();
}

@DataClassName('BudgetRow')
class Budgets extends Table {
  TextColumn get category => text()();
  RealColumn get monthlyLimit => real()();

  // Sync columns
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {category};
}

@DataClassName('RecurringRuleRow')
class RecurringRules extends Table {
  TextColumn get syncId => text()();
  RealColumn get amount => real()();
  TextColumn get type => text()();
  TextColumn get category => text()();
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get frequency => text()(); // 'weekly' or 'monthly'
  DateTimeColumn get startDate => dateTime()();

  // Sync columns
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {syncId};
}

@DriftDatabase(tables: [Transactions, Budgets, RecurringRules])
class AppDatabase extends _$AppDatabase {
  AppDatabase({String userId = 'guest'})
    : super(driftDatabase(name: 'spendly_$userId'));

  // Used in tests with an in-memory database.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(budgets);
      }
      if (from < 3) {
        await m.addColumn(transactions, transactions.syncId);
        await m.addColumn(transactions, transactions.updatedAt);
        await m.addColumn(transactions, transactions.deleted);
        await m.addColumn(transactions, transactions.dirty);
        await m.addColumn(budgets, budgets.updatedAt);
        await m.addColumn(budgets, budgets.deleted);
        await m.addColumn(budgets, budgets.dirty);

        // Give every existing row a sync id and a timestamp.
        final now = DateTime.now().millisecondsSinceEpoch;
        const uuid = Uuid();
        final rows = await select(transactions).get();
        for (final r in rows) {
          await (update(transactions)..where((t) => t.id.equals(r.id))).write(
            TransactionsCompanion(
              syncId: Value(uuid.v4()),
              updatedAt: Value(now),
            ),
          );
        }
        await update(budgets).write(BudgetsCompanion(updatedAt: Value(now)));
      }
      if (from < 4) {
        await m.createTable(recurringRules);
      }
    },
  );
}
