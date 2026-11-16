import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly_android/app.dart';
import 'package:spendly_android/data/models/transaction.dart';
import 'package:spendly_android/data/repositories/transaction_repository.dart';
import 'package:spendly_android/features/transactions/application/transactions_provider.dart';
import 'package:spendly_android/data/models/budget.dart';
import 'package:spendly_android/data/repositories/budget_repository.dart';
import 'package:spendly_android/features/budgets/application/budgets_provider.dart';
import 'package:spendly_android/data/models/app_user.dart';
import 'package:spendly_android/features/auth/application/auth_provider.dart';

import 'helpers/fake_auth_repository.dart';

import 'package:spendly_android/features/sync/application/sync_provider.dart';
import 'package:spendly_android/features/recurring/application/recurring_provider.dart';

class FakeTransactionRepository implements TransactionRepository {
  final _items = <AppTransaction>[];
  var _nextId = 1;

  @override
  Future<List<AppTransaction>> getAll() async => List.of(_items);

  @override
  Future<void> add(AppTransaction t) async {
    final id = t.id == 0 ? _nextId++ : t.id;
    _items.insert(
      0,
      AppTransaction(
        id: id,
        amount: t.amount,
        type: t.type,
        category: t.category,
        note: t.note,
        date: t.date,
      ),
    );
  }

  @override
  Future<void> remove(int id) async => _items.removeWhere((t) => t.id == id);
}

class FakeBudgetRepository implements BudgetRepository {
  final _items = <String, Budget>{};

  @override
  Future<List<Budget>> getAll() async => _items.values.toList();

  @override
  Future<void> upsert(Budget budget) async => _items[budget.category] = budget;

  @override
  Future<void> remove(String category) async => _items.remove(category);
}

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets('add a transaction and see it in the list', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(
            FakeTransactionRepository(),
          ),
          budgetRepositoryProvider.overrideWithValue(FakeBudgetRepository()),
          remoteStoreProvider.overrideWithValue(null), // no cloud in tests
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(
              user: const AppUser(
                uid: 'test',
                email: 'test@example.com',
                emailVerified: true,
              ),
            ),
          ),
          dueGeneratorProvider.overrideWithValue(
            (now) async => 0,
          ), // no real database
        ],
        child: const SpendlyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No transactions yet'), findsOneWidget);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '1500');
    await tester.ensureVisible(find.text('Save transaction'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();

    expect(find.text('Save transaction'), findsNothing); // the form closed
    expect(find.text('No transactions yet'), findsNothing);
    expect(find.text('Food'), findsOneWidget);
  });
}
