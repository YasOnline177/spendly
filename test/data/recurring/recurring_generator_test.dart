import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly_android/data/database/app_database.dart';
import 'package:spendly_android/data/models/transaction.dart';
import 'package:spendly_android/data/recurring/recurring_generator.dart';
import 'package:spendly_android/data/repositories/drift_transaction_repository.dart';

Future<void> _addRule(
  AppDatabase db, {
  String syncId = 'rule-1',
  String frequency = 'monthly',
  required DateTime start,
  bool deleted = false,
}) async {
  await db.into(db.recurringRules).insert(
        RecurringRulesCompanion.insert(
          syncId: syncId,
          amount: 45000,
          type: 'expense',
          category: 'Bills',
          note: const Value('Rent'),
          frequency: frequency,
          startDate: start,
          deleted: Value(deleted),
        ),
      );
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late RecurringGenerator generator;
  late DriftTransactionRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    generator = RecurringGenerator(db);
    repo = DriftTransactionRepository(db);
  });

  tearDown(() => db.close());

  test('creates every due occurrence up to today', () async {
    await _addRule(db, start: DateTime(2026, 8, 15));

    final created = await generator.generateDue(DateTime(2026, 10, 20));

    expect(created, 3);
    final all = await repo.getAll();
    expect(all.map((t) => t.date), [
      DateTime(2026, 10, 15),
      DateTime(2026, 9, 15),
      DateTime(2026, 8, 15),
    ]);
    expect(
      all.every(
        (t) => t.amount == 45000 && t.category == 'Bills' && t.note == 'Rent',
      ),
      isTrue,
    );
  });

  test('generated rows have a deterministic id and are marked for syncing',
      () async {
    await _addRule(db, start: DateTime(2026, 10, 15));

    await generator.generateDue(DateTime(2026, 10, 20));

    final row = (await db.select(db.transactions).get()).single;
    expect(row.syncId, 'rule-1:20261015');
    expect(row.dirty, isTrue);
    expect(row.updatedAt, DateTime(2026, 10, 15).millisecondsSinceEpoch);
  });

  test('running again creates nothing and keeps the user\'s edits', () async {
    await _addRule(db, start: DateTime(2026, 10, 15));
    await generator.generateDue(DateTime(2026, 10, 20));

    final generated = (await repo.getAll()).single;
    await repo.add(
      AppTransaction(
        id: generated.id,
        amount: 50000,
        type: generated.type,
        category: generated.category,
        note: generated.note,
        date: generated.date,
      ),
    );

    final created = await generator.generateDue(DateTime(2026, 10, 20));

    expect(created, 0);
    final all = await repo.getAll();
    expect(all, hasLength(1));
    expect(all.single.amount, 50000);
  });

  test('a deleted generated transaction is not brought back', () async {
    await _addRule(db, start: DateTime(2026, 9, 15));
    await generator.generateDue(DateTime(2026, 10, 20));

    final newest = (await repo.getAll()).first;
    await repo.remove(newest.id);

    final created = await generator.generateDue(DateTime(2026, 10, 20));

    expect(created, 0);
    expect(await repo.getAll(), hasLength(1));
  });

  test('new occurrences appear as time passes', () async {
    await _addRule(db, start: DateTime(2026, 8, 15));

    expect(await generator.generateDue(DateTime(2026, 10, 20)), 3);
    expect(await generator.generateDue(DateTime(2026, 11, 16)), 1);

    expect(await repo.getAll(), hasLength(4));
  });

  test('a rule that has not started yet creates nothing', () async {
    await _addRule(db, start: DateTime(2026, 12, 1));

    expect(await generator.generateDue(DateTime(2026, 11, 16)), 0);
    expect(await repo.getAll(), isEmpty);
  });

  test('a deleted rule creates nothing', () async {
    await _addRule(db, start: DateTime(2026, 8, 15), deleted: true);

    expect(await generator.generateDue(DateTime(2026, 10, 20)), 0);
  });

  test('two devices generate identical ids, so syncing cannot duplicate them',
      () async {
    final other = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(other.close);

    await _addRule(db, start: DateTime(2026, 9, 1));
    await _addRule(other, start: DateTime(2026, 9, 1));

    await generator.generateDue(DateTime(2026, 11, 16));
    await RecurringGenerator(other).generateDue(DateTime(2026, 11, 16));

    Future<Set<String?>> ids(AppDatabase d) async =>
        (await d.select(d.transactions).get()).map((t) => t.syncId).toSet();

    expect(await ids(db), await ids(other));
    expect(await ids(db), hasLength(3));
  });
}