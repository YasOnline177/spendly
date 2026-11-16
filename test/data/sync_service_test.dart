import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly_android/data/database/app_database.dart';
import 'package:spendly_android/data/models/budget.dart';
import 'package:spendly_android/data/models/transaction.dart';
import 'package:spendly_android/data/repositories/drift_budget_repository.dart';
import 'package:spendly_android/data/repositories/drift_transaction_repository.dart';
import 'package:spendly_android/data/sync/sync_service.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:spendly_android/data/models/recurring_rule.dart';
import 'package:spendly_android/data/recurring/recurrence.dart';
import 'package:spendly_android/data/recurring/recurring_generator.dart';
import 'package:spendly_android/data/repositories/drift_recurring_rule_repository.dart';

import '../helpers/fake_remote_store.dart';

AppTransaction _tx(String category, {int id = 0, double amount = 1000}) {
  return AppTransaction(
    id: id,
    amount: amount,
    type: TransactionType.expense,
    category: category,
    note: '',
    date: DateTime(2026, 10, 1),
  );
}

/// One simulated phone: its own database, its own clock, same shared cloud.
class _Device {
  _Device(FakeRemoteStore cloud)
    : db = AppDatabase.forTesting(NativeDatabase.memory()) {
    txRepo = DriftTransactionRepository(db, now: () => clock);
    budgetRepo = DriftBudgetRepository(db, now: () => clock);
    ruleRepo = DriftRecurringRuleRepository(db, now: () => clock);
    generator = RecurringGenerator(db);
    sync = SyncService(db, cloud);
  }

  final AppDatabase db;
  DateTime clock = DateTime(2026, 10, 1, 12);
  late final DriftTransactionRepository txRepo;
  late final DriftBudgetRepository budgetRepo;
  late final DriftRecurringRuleRepository ruleRepo;
  late final RecurringGenerator generator;
  late final SyncService sync;

  void advance(Duration d) => clock = clock.add(d);

  Future<int> onlyTransactionId() async => (await txRepo.getAll()).single.id;

  Future<void> close() => db.close();
}

RecurringRule _rule(String id, DateTime start) {
  return RecurringRule(
    syncId: id,
    amount: 45000,
    type: TransactionType.expense,
    category: 'Bills',
    note: 'Rent',
    frequency: Frequency.monthly,
    startDate: start,
  );
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases =
      true; // each "device" has its own in-memory DB
  late FakeRemoteStore cloud;
  late _Device a;
  late _Device b;

  setUp(() {
    cloud = FakeRemoteStore();
    a = _Device(cloud);
    b = _Device(cloud);
  });

  tearDown(() async {
    await a.close();
    await b.close();
  });

  test('uploads new local rows and marks them clean', () async {
    await a.txRepo.add(_tx('Food'));

    await a.sync.sync();

    expect(cloud.transactions, hasLength(1));
    expect(cloud.transactions.values.single.category, 'Food');
    final row = (await a.db.select(a.db.transactions).get()).single;
    expect(row.dirty, isFalse);
  });

  test('a second sync with no changes uploads nothing', () async {
    await a.txRepo.add(_tx('Food'));
    await a.sync.sync();
    final pushed = cloud.pushedTransactions;

    await a.sync.sync();

    expect(cloud.pushedTransactions, pushed);
  });

  test('a new device downloads existing transactions and budgets', () async {
    await a.txRepo.add(_tx('Food'));
    await a.budgetRepo.upsert(const Budget(category: 'Food', limit: 5000));
    await a.sync.sync();

    await b.sync.sync();

    expect((await b.txRepo.getAll()).single.category, 'Food');
    expect((await b.budgetRepo.getAll()).single.limit, 5000);
  });

  test('an edit on one device reaches the other', () async {
    await a.txRepo.add(_tx('Food', amount: 100));
    await a.sync.sync();
    await b.sync.sync();

    b.advance(const Duration(minutes: 5));
    final id = await b.onlyTransactionId();
    await b.txRepo.add(_tx('Food', id: id, amount: 999));
    await b.sync.sync();
    await a.sync.sync();

    expect((await a.txRepo.getAll()).single.amount, 999);
  });

  test('conflict: the most recent edit wins everywhere', () async {
    await a.txRepo.add(_tx('Food', amount: 100));
    await a.sync.sync();
    await b.sync.sync();

    // Both edit the same row while "offline"; B edits later.
    a.advance(const Duration(minutes: 1));
    await a.txRepo.add(
      _tx('Food', id: await a.onlyTransactionId(), amount: 111),
    );
    b.advance(const Duration(minutes: 2));
    await b.txRepo.add(
      _tx('Food', id: await b.onlyTransactionId(), amount: 222),
    );

    await a.sync.sync(); // uploads 111
    await b.sync.sync(); // sees older 111, keeps its own 222, uploads it
    await a.sync.sync(); // downloads 222

    expect((await a.txRepo.getAll()).single.amount, 222);
    expect((await b.txRepo.getAll()).single.amount, 222);
    expect(cloud.transactions.values.single.amount, 222);
  });

  test('deleting on one device deletes on the other', () async {
    await a.txRepo.add(_tx('Food'));
    await a.sync.sync();
    await b.sync.sync();
    expect(await b.txRepo.getAll(), hasLength(1));

    a.advance(const Duration(minutes: 1));
    await a.txRepo.remove(await a.onlyTransactionId());
    await a.sync.sync();
    await b.sync.sync();

    expect(await b.txRepo.getAll(), isEmpty);
    expect(cloud.transactions.values.single.deleted, isTrue);
  });

  test(
    'a row deleted in the cloud is not recreated on a fresh device',
    () async {
      await a.txRepo.add(_tx('Food'));
      await a.sync.sync();
      a.advance(const Duration(minutes: 1));
      await a.txRepo.remove(await a.onlyTransactionId());
      await a.sync.sync();

      await b.sync.sync();

      expect(await b.db.select(b.db.transactions).get(), isEmpty);
    },
  );

  test('budget changes and deletions sync', () async {
    await a.budgetRepo.upsert(const Budget(category: 'Food', limit: 5000));
    await a.sync.sync();
    await b.sync.sync();
    expect((await b.budgetRepo.getAll()).single.limit, 5000);

    b.advance(const Duration(minutes: 1));
    await b.budgetRepo.remove('Food');
    await b.sync.sync();
    await a.sync.sync();

    expect(await a.budgetRepo.getAll(), isEmpty);
  });

  test(
    'a rule syncs, and the other device does not duplicate its transactions',
    () async {
      final today = DateTime(2026, 11, 16);
      await a.ruleRepo.add(_rule('rule-1', DateTime(2026, 9, 1)));
      await a.generator.generateDue(today); // Sep 1, Oct 1, Nov 1
      await a.sync.sync();

      await b.sync.sync(); // downloads the rule and A's 3 transactions

      expect(await b.generator.generateDue(today), 0);
      expect(await b.txRepo.getAll(), hasLength(3));
      expect(await b.ruleRepo.getAll(), hasLength(1));
    },
  );

  test(
    'both devices generate while offline, then sync without duplicates',
    () async {
      final today = DateTime(2026, 11, 16);
      await a.ruleRepo.add(_rule('rule-1', DateTime(2026, 9, 1)));
      await a.sync.sync();
      await b.sync.sync();

      // Each device creates the same three occurrences on its own.
      await a.generator.generateDue(today);
      await b.generator.generateDue(today);

      await a.sync.sync();
      await b.sync.sync();
      await a.sync.sync();

      expect(await a.txRepo.getAll(), hasLength(3));
      expect(await b.txRepo.getAll(), hasLength(3));
      expect(cloud.transactions, hasLength(3));
    },
  );

  test('deleting a rule on one device stops it on the other', () async {
    await a.ruleRepo.add(_rule('rule-1', DateTime(2026, 9, 1)));
    await a.sync.sync();
    await b.sync.sync();

    a.advance(const Duration(minutes: 1));
    await a.ruleRepo.remove('rule-1');
    await a.sync.sync();
    await b.sync.sync();

    expect(await b.ruleRepo.getAll(), isEmpty);
    expect(await b.generator.generateDue(DateTime(2026, 11, 16)), 0);
  });
}
