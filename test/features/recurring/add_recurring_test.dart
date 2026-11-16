import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly_android/data/models/recurring_rule.dart';
import 'package:spendly_android/data/recurring/recurrence.dart';
import 'package:spendly_android/data/repositories/recurring_rule_repository.dart';
import 'package:spendly_android/features/recurring/application/recurring_provider.dart';
import 'package:spendly_android/features/sync/application/sync_provider.dart';
import 'package:spendly_android/features/transactions/presentation/add_transaction_screen.dart';

class FakeRecurringRuleRepository implements RecurringRuleRepository {
  final items = <RecurringRule>[];

  @override
  Future<List<RecurringRule>> getAll() async => List.of(items);

  @override
  Future<void> add(RecurringRule rule) async {
    items.removeWhere((r) => r.syncId == rule.syncId);
    items.add(rule);
  }

  @override
  Future<void> remove(String syncId) async =>
      items.removeWhere((r) => r.syncId == syncId);
}

void main() {
  testWidgets('choosing Monthly creates a recurring rule', (tester) async {
    final repo = FakeRecurringRuleRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recurringRuleRepositoryProvider.overrideWithValue(repo),
          dueGeneratorProvider.overrideWithValue((now) async => 0),
          remoteStoreProvider.overrideWithValue(null),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddTransactionScreen(),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '45000');
    await tester.ensureVisible(find.text('Monthly'));
    await tester.tap(find.text('Monthly'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save transaction'));
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();

    expect(repo.items, hasLength(1));
    expect(repo.items.single.amount, 45000);
    expect(repo.items.single.frequency, Frequency.monthly);
  });
}