import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly_android/data/database/app_database.dart';
import 'package:spendly_android/data/models/budget.dart';
import 'package:spendly_android/data/repositories/drift_budget_repository.dart';

void main() {
  late AppDatabase db;
  late DriftBudgetRepository repo;
  late DateTime clock;

  setUp(() {
    clock = DateTime(2026, 10, 1, 12);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftBudgetRepository(db, now: () => clock);
  });

  tearDown(() => db.close());

  test('upsert on the same category replaces the limit', () async {
    await repo.upsert(const Budget(category: 'Food', limit: 5000));
    await repo.upsert(const Budget(category: 'Food', limit: 8000));

    final all = await repo.getAll();
    expect(all, hasLength(1));
    expect(all.single.limit, 8000);
  });

  test('remove hides only that category', () async {
    await repo.upsert(const Budget(category: 'Food', limit: 5000));
    await repo.upsert(const Budget(category: 'Bills', limit: 3000));

    await repo.remove('Food');

    final all = await repo.getAll();
    expect(all.map((b) => b.category), ['Bills']);
  });

  test('remove is a soft delete and upsert revives the budget', () async {
    await repo.upsert(const Budget(category: 'Food', limit: 5000));

    clock = clock.add(const Duration(minutes: 1));
    await repo.remove('Food');

    var row = (await db.select(db.budgets).get()).single;
    expect(row.deleted, isTrue);
    expect(row.dirty, isTrue);
    expect(row.updatedAt, clock.millisecondsSinceEpoch);

    clock = clock.add(const Duration(minutes: 1));
    await repo.upsert(const Budget(category: 'Food', limit: 6000));

    row = (await db.select(db.budgets).get()).single;
    expect(row.deleted, isFalse);
    expect((await repo.getAll()).single.limit, 6000);
  });
}