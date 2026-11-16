import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly_android/data/models/recurring_rule.dart';
import 'package:spendly_android/data/models/transaction.dart';
import 'package:spendly_android/data/recurring/recurrence.dart';
import 'package:spendly_android/features/recurring/application/recurring_provider.dart';
import 'package:spendly_android/features/recurring/presentation/recurring_screen.dart';
import 'package:spendly_android/features/sync/application/sync_provider.dart';

import 'add_recurring_test.dart' show FakeRecurringRuleRepository;

Widget _app(FakeRecurringRuleRepository repo) {
  return ProviderScope(
    overrides: [
      recurringRuleRepositoryProvider.overrideWithValue(repo),
      remoteStoreProvider.overrideWithValue(null),
    ],
    child: const MaterialApp(home: RecurringScreen()),
  );
}

RecurringRule _rent() {
  return RecurringRule(
    syncId: 'rule-1',
    amount: 45000,
    type: TransactionType.expense,
    category: 'Bills',
    note: 'Rent',
    frequency: Frequency.monthly,
    startDate: DateTime(2026, 10, 15),
  );
}

void main() {
  testWidgets('shows an empty state when there are no rules', (tester) async {
    await tester.pumpWidget(_app(FakeRecurringRuleRepository()));
    await tester.pumpAndSettle();

    expect(find.text('No recurring transactions'), findsOneWidget);
  });

  testWidgets('lists rules with their schedule', (tester) async {
    final repo = FakeRecurringRuleRepository()..items.add(_rent());

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Bills · Rent'), findsOneWidget);
    expect(find.textContaining('Monthly on day 15'), findsOneWidget);
  });

  testWidgets('swiping a rule deletes it', (tester) async {
    final repo = FakeRecurringRuleRepository()..items.add(_rent());

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Bills · Rent'), const Offset(-800, 0));
    await tester.pumpAndSettle();

    expect(find.text('Bills · Rent'), findsNothing);
    expect(repo.items, isEmpty);
  });
}