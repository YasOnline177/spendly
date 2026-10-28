import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly_android/data/database/app_database.dart';
import 'package:spendly_android/data/models/budget.dart';
import 'package:spendly_android/data/models/transaction.dart';
import 'package:spendly_android/data/repositories/drift_budget_repository.dart';
import 'package:spendly_android/data/repositories/drift_transaction_repository.dart';
import 'package:spendly_android/data/sync/sync_service.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;

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
    sync = SyncService(db, cloud);
  }

  final AppDatabase db;
  DateTime clock = DateTime(2026, 10, 1, 12);
  late final DriftTransactionRepository txRepo;
  late final DriftBudgetRepository budgetRepo;
  late final SyncService sync;

  void advance(Duration d) => clock = clock.add(d);

  Future<int> onlyTransactionId() async =>
      (await txRepo.getAll()).single.id;

  Future<void> close() => db.close();
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;  // each "device" has its own in-memory DB
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
    await a.txRepo.add(_tx('Food', id: await a.onlyTransactionId(), amount: 111));
    b.advance(const Duration(minutes: 2));
    await b.txRepo.add(_tx('Food', id: await b.onlyTransactionId(), amount: 222));

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

  test('a row deleted in the cloud is not recreated on a fresh device',
      () async {
    await a.txRepo.add(_tx('Food'));
    await a.sync.sync();
    a.advance(const Duration(minutes: 1));
    await a.txRepo.remove(await a.onlyTransactionId());
    await a.sync.sync();

    await b.sync.sync();

    expect(await b.db.select(b.db.transactions).get(), isEmpty);
  });

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
}