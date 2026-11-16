import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly_android/data/database/app_database.dart';
import 'package:spendly_android/data/models/recurring_rule.dart';
import 'package:spendly_android/data/models/transaction.dart';
import 'package:spendly_android/data/recurring/recurrence.dart';
import 'package:spendly_android/data/repositories/drift_recurring_rule_repository.dart';

RecurringRule _rule({String id = 'rule-1'}) {
  return RecurringRule(
    syncId: id,
    amount: 45000,
    type: TransactionType.expense,
    category: 'Bills',
    note: 'Rent',
    frequency: Frequency.monthly,
    startDate: DateTime(2026, 10, 15),
  );
}

void main() {
  late AppDatabase db;
  late DriftRecurringRuleRepository repo;
  late DateTime clock;

  setUp(() {
    clock = DateTime(2026, 10, 1, 12);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftRecurringRuleRepository(db, now: () => clock);
  });

  tearDown(() => db.close());

  test('add then getAll returns the rule with all its fields', () async {
    await repo.add(_rule());

    final rule = (await repo.getAll()).single;
    expect(rule.syncId, 'rule-1');
    expect(rule.amount, 45000);
    expect(rule.type, TransactionType.expense);
    expect(rule.category, 'Bills');
    expect(rule.note, 'Rent');
    expect(rule.frequency, Frequency.monthly);
    expect(rule.startDate, DateTime(2026, 10, 15));
  });

  test('add stamps sync metadata', () async {
    await repo.add(_rule());

    final row = (await db.select(db.recurringRules).get()).single;
    expect(row.dirty, isTrue);
    expect(row.deleted, isFalse);
    expect(row.updatedAt, clock.millisecondsSinceEpoch);
  });

  test('remove is a soft delete and add with the same id restores it',
      () async {
    await repo.add(_rule());

    clock = clock.add(const Duration(minutes: 1));
    await repo.remove('rule-1');

    expect(await repo.getAll(), isEmpty);
    var row = (await db.select(db.recurringRules).get()).single;
    expect(row.deleted, isTrue);
    expect(row.dirty, isTrue);

    clock = clock.add(const Duration(minutes: 1));
    await repo.add(_rule());

    row = (await db.select(db.recurringRules).get()).single;
    expect(row.deleted, isFalse);
    expect(await repo.getAll(), hasLength(1));
  });
}