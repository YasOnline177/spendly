import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly_android/data/database/app_database.dart';
import 'package:spendly_android/data/models/transaction.dart';
import 'package:spendly_android/data/repositories/drift_transaction_repository.dart';

AppTransaction _tx({int id = 0, String category = 'Food', DateTime? date}) {
  return AppTransaction(
    id: id,
    amount: 1000,
    type: TransactionType.expense,
    category: category,
    note: '',
    date: date ?? DateTime(2026, 10, 1),
  );
}

void main() {
  late AppDatabase db;
  late DriftTransactionRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftTransactionRepository(db);
  });

  tearDown(() => db.close());

  test('add assigns an id and getAll returns the item', () async {
    await repo.add(_tx());
    final all = await repo.getAll();

    expect(all, hasLength(1));
    expect(all.first.id, isNonZero);
    expect(all.first.category, 'Food');
  });

  test('getAll returns newest date first', () async {
    await repo.add(_tx(category: 'Old', date: DateTime(2026, 9, 1)));
    await repo.add(_tx(category: 'New', date: DateTime(2026, 10, 1)));

    final all = await repo.getAll();
    expect(all.map((t) => t.category), ['New', 'Old']);
  });

  test('remove deletes and re-adding with the same id restores it', () async {
    await repo.add(_tx());
    final saved = (await repo.getAll()).first;

    await repo.remove(saved.id);
    expect(await repo.getAll(), isEmpty);

    await repo.add(saved); // this is what Undo does
    final restored = await repo.getAll();
    expect(restored.single.id, saved.id);
  });

  test('add with an existing id replaces that row (edit)', () async {
    await repo.add(_tx(category: 'Food'));
    final saved = (await repo.getAll()).single;

    await repo.add(
      AppTransaction(
        id: saved.id,
        amount: 2500,
        type: saved.type,
        category: 'Bills',
        note: 'edited',
        date: saved.date,
      ),
    );

    final all = await repo.getAll();
    expect(all, hasLength(1));
    expect(all.single.category, 'Bills');
    expect(all.single.amount, 2500);
  });
}