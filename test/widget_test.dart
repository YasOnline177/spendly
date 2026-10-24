import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly_android/app.dart';
import 'package:spendly_android/data/models/transaction.dart';
import 'package:spendly_android/data/repositories/transaction_repository.dart';
import 'package:spendly_android/features/transactions/application/transactions_provider.dart';

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

void main() {
  testWidgets('add a transaction and see it in the list', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider
              .overrideWithValue(FakeTransactionRepository()),
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
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();

    expect(find.text('No transactions yet'), findsNothing);
    expect(find.text('Food'), findsOneWidget);
  });
}