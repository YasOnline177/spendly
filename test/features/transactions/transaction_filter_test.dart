import 'package:flutter_test/flutter_test.dart';
import 'package:spendly_android/data/models/transaction.dart';
import 'package:spendly_android/features/transactions/application/transaction_filter.dart';

AppTransaction _tx(
  int id,
  double amount,
  String category, {
  String note = '',
  TransactionType type = TransactionType.expense,
  required DateTime date,
}) {
  return AppTransaction(
    id: id,
    amount: amount,
    type: type,
    category: category,
    note: note,
    date: date,
  );
}

List<int> _ids(List<AppTransaction> list) => list.map((t) => t.id).toList();

void main() {
  final txs = [
    _tx(1, 1500, 'Food', note: 'Lunch at Majestic', date: DateTime(2026, 10, 3)),
    _tx(2, 300, 'Transport', note: 'Bus', date: DateTime(2026, 10, 5)),
    _tx(3, 50000, 'Salary',
        type: TransactionType.income, date: DateTime(2026, 10, 1)),
    _tx(4, 800, 'Food', note: 'Coffee', date: DateTime(2026, 10, 10, 15, 30)),
  ];

  test('default filter returns everything, newest first', () {
    expect(_ids(applyFilter(txs, const TransactionFilter())), [4, 2, 1, 3]);
  });

  group('search', () {
    test('matches note text, ignoring case', () {
      final r = applyFilter(txs, const TransactionFilter(query: 'LUNCH'));
      expect(_ids(r), [1]);
    });

    test('matches category', () {
      final r = applyFilter(txs, const TransactionFilter(query: 'food'));
      expect(_ids(r), [4, 1]);
    });

    test('matches amount', () {
      final r = applyFilter(txs, const TransactionFilter(query: '300'));
      expect(_ids(r), [2]);
    });

    test('whitespace-only query matches everything', () {
      final r = applyFilter(txs, const TransactionFilter(query: '   '));
      expect(r, hasLength(4));
    });
  });

  test('filters by type', () {
    final income = applyFilter(
      txs,
      const TransactionFilter(type: TransactionType.income),
    );
    final expense = applyFilter(
      txs,
      const TransactionFilter(type: TransactionType.expense),
    );

    expect(_ids(income), [3]);
    expect(expense, hasLength(3));
  });

  test('filters by several categories', () {
    final r = applyFilter(
      txs,
      const TransactionFilter(categories: {'Food', 'Transport'}),
    );
    expect(_ids(r), [4, 2, 1]);
  });

  test('date range includes the whole last day', () {
    final r = applyFilter(
      txs,
      TransactionFilter(from: DateTime(2026, 10, 3), to: DateTime(2026, 10, 10)),
    );
    // #4 happened at 15:30 on the last day and must still be included.
    expect(_ids(r), [4, 2, 1]);
  });

  group('sorting', () {
    test('oldest first', () {
      final r = applyFilter(txs, const TransactionFilter(sort: SortOption.oldest));
      expect(_ids(r), [3, 1, 2, 4]);
    });

    test('highest amount first', () {
      final r =
          applyFilter(txs, const TransactionFilter(sort: SortOption.highest));
      expect(_ids(r), [3, 1, 4, 2]);
    });

    test('lowest amount first', () {
      final r = applyFilter(txs, const TransactionFilter(sort: SortOption.lowest));
      expect(_ids(r), [2, 4, 1, 3]);
    });
  });

  test('filters combine', () {
    final r = applyFilter(
      txs,
      const TransactionFilter(
        query: 'food',
        type: TransactionType.expense,
        sort: SortOption.lowest,
      ),
    );
    expect(_ids(r), [4, 1]);
  });

  group('isActive', () {
    test('is false by default and for blank search', () {
      expect(const TransactionFilter().isActive, isFalse);
      expect(const TransactionFilter(query: '  ').isActive, isFalse);
    });

    test('is true when anything is set', () {
      expect(const TransactionFilter(query: 'a').isActive, isTrue);
      expect(const TransactionFilter(categories: {'Food'}).isActive, isTrue);
      expect(const TransactionFilter(sort: SortOption.oldest).isActive, isTrue);
    });

    test('search text alone is not a "sheet" filter', () {
      expect(const TransactionFilter(query: 'a').hasSheetFilters, isFalse);
    });
  });
}