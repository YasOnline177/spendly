import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

@DataClassName('TransactionRow')
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get amount => real()();
  TextColumn get type => text()(); // 'income' or 'expense'
  TextColumn get category => text()();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get date => dateTime()();
}

@DataClassName('BudgetRow')
class Budgets extends Table {
  TextColumn get category => text()();
  RealColumn get monthlyLimit => real()();

  @override
  Set<Column> get primaryKey => {category};
}

@DriftDatabase(tables: [Transactions, Budgets])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'spendly'));

  // Used in tests with an in-memory database.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(budgets);
      }
    },
  );
}
