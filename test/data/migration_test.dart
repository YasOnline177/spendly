import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly_android/data/database/app_database.dart';

void main() {
  test('migrating v2 to v3 keeps data and adds sync metadata', () async {
    // Build a database exactly as schema v2 left it.
    final db = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('''
            CREATE TABLE transactions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              amount REAL NOT NULL,
              type TEXT NOT NULL,
              category TEXT NOT NULL,
              note TEXT NOT NULL DEFAULT '',
              date INTEGER NOT NULL
            );
            CREATE TABLE budgets (
              category TEXT NOT NULL PRIMARY KEY,
              monthly_limit REAL NOT NULL
            );
            INSERT INTO transactions (amount, type, category, note, date)
              VALUES (1500, 'expense', 'Food', 'lunch', 1760000000),
                     (800, 'expense', 'Transport', '', 1760000100);
            INSERT INTO budgets (category, monthly_limit) VALUES ('Food', 5000);
            PRAGMA user_version = 2;
          ''');
        },
      ),
    );

    // Opening the database runs the migration.
    final txs = await db.select(db.transactions).get();
    final budgets = await db.select(db.budgets).get();

    expect(txs, hasLength(2));
    expect(txs.map((t) => t.category), containsAll(['Food', 'Transport']));
    expect(txs.every((t) => t.syncId != null && t.syncId!.length == 36), isTrue);
    expect(txs.map((t) => t.syncId).toSet(), hasLength(2)); // all unique
    expect(txs.every((t) => t.updatedAt > 0), isTrue);
    expect(txs.every((t) => t.dirty && !t.deleted), isTrue);

    expect(budgets.single.category, 'Food');
    expect(budgets.single.monthlyLimit, 5000);
    expect(budgets.single.updatedAt, greaterThan(0));
    expect(budgets.single.dirty, isTrue);

    await db.close();
  });
}