import 'package:flutter_test/flutter_test.dart';
import 'package:spendly_android/data/models/transaction.dart';
import 'package:spendly_android/features/export/application/csv_export.dart';

AppTransaction _tx({
  int id = 1,
  double amount = 1500,
  String category = 'Food',
  String note = '',
  TransactionType type = TransactionType.expense,
  DateTime? date,
}) {
  return AppTransaction(
    id: id,
    amount: amount,
    type: type,
    category: category,
    note: note,
    date: date ?? DateTime(2026, 11, 3),
  );
}

void main() {
  group('buildTransactionsCsv', () {
    test('writes a BOM, a header and one row per transaction with CRLF', () {
      final csv = buildTransactionsCsv([_tx(note: 'Lunch')]);

      expect(
        csv,
        '\uFEFFDate,Type,Category,Amount,Note\r\n'
        '2026-11-03,Expense,Food,1500.00,Lunch\r\n',
      );
    });

    test('an empty list exports just the header', () {
      expect(
        buildTransactionsCsv([]),
        '\uFEFFDate,Type,Category,Amount,Note\r\n',
      );
    });

    test('amounts are plain numbers with two decimals', () {
      final csv = buildTransactionsCsv([
        _tx(amount: 1234567.5),
        _tx(id: 2, amount: 0.1 + 0.2),
      ]);

      expect(csv, contains(',1234567.50,'));
      expect(csv, contains(',0.30,'));
      expect(csv, isNot(contains('LKR')));
    });

    test('labels income and expense', () {
      final csv = buildTransactionsCsv([
        _tx(type: TransactionType.income, category: 'Salary'),
      ]);
      expect(csv, contains('2026-11-03,Income,Salary,1500.00,'));
    });

    test('sorts oldest first, and by id on the same day', () {
      final csv = buildTransactionsCsv([
        _tx(id: 3, category: 'C', date: DateTime(2026, 11, 5)),
        _tx(id: 2, category: 'B', date: DateTime(2026, 11, 1)),
        _tx(id: 1, category: 'A', date: DateTime(2026, 11, 1)),
      ]);

      final categories = csv
          .trim()
          .split('\r\n')
          .skip(1)
          .map((line) => line.split(',')[2])
          .toList();
      expect(categories, ['A', 'B', 'C']);
    });

    test('dates keep a leading zero for months and days', () {
      final csv = buildTransactionsCsv([_tx(date: DateTime(2026, 1, 5))]);
      expect(csv, contains('2026-01-05,'));
    });

    test('keeps non-English text', () {
      final csv = buildTransactionsCsv([_tx(note: 'කෑම – lunch')]);
      expect(csv, contains('කෑම – lunch'));
    });
  });

  group('escapeCsvField', () {
    test('leaves plain text alone', () {
      expect(escapeCsvField('Lunch'), 'Lunch');
    });

    test('quotes text with a comma', () {
      expect(escapeCsvField('rice, curry'), '"rice, curry"');
    });

    test('doubles quotes inside quoted text', () {
      expect(escapeCsvField('with "friends"'), '"with ""friends"""');
    });

    test('quotes text with a line break', () {
      expect(escapeCsvField('line1\nline2'), '"line1\nline2"');
    });

    test('a note with every special character stays in one field', () {
      final csv = buildTransactionsCsv([_tx(note: 'a, "b"\nc')]);
      expect(csv, endsWith(',"a, ""b""\nc"\r\n'));
    });

    test('stops spreadsheet formulas from running', () {
      expect(escapeCsvField('=SUM(A1:A9)'), "'=SUM(A1:A9)");
      expect(escapeCsvField('+94 77 123 4567'), "'+94 77 123 4567");
      expect(escapeCsvField('-5 refund'), "'-5 refund");
      expect(escapeCsvField('@user'), "'@user");
    });

    test('a dangerous value with a comma is both defused and quoted', () {
      expect(escapeCsvField('=1,2'), '"\'=1,2"');
    });
  });

  test('exportFileName uses the export date', () {
    expect(
      exportFileName(DateTime(2026, 11, 28)),
      'spendly-transactions-2026-11-28.csv',
    );
  });
}