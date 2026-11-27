import 'package:flutter_test/flutter_test.dart';
import 'package:spendly_android/data/models/transaction.dart';
import 'package:spendly_android/features/export/application/export_service.dart';

import '../../helpers/fake_file_sharer.dart';

AppTransaction _tx() {
  return AppTransaction(
    id: 1,
    amount: 1500,
    type: TransactionType.expense,
    category: 'Food',
    note: 'Lunch',
    date: DateTime(2026, 11, 3),
  );
}

void main() {
  final now = DateTime(2026, 11, 28);

  test('shares a CSV file named after the export date', () async {
    final sharer = FakeFileSharer();

    final result = await ExportService(sharer).exportTransactions([_tx()], now);

    expect(result, ExportResult.shared);
    final file = sharer.files.single;
    expect(file.fileName, 'spendly-transactions-2026-11-28.csv');
    expect(file.mimeType, 'text/csv');
    expect(file.content, contains('2026-11-03,Expense,Food,1500.00,Lunch'));
  });

  test('does not share anything when there is nothing to export', () async {
    final sharer = FakeFileSharer();

    final result = await ExportService(sharer).exportTransactions([], now);

    expect(result, ExportResult.empty);
    expect(sharer.files, isEmpty);
  });

  test('reports a failure instead of throwing', () async {
    final sharer = FakeFileSharer()..fail = true;

    final result = await ExportService(sharer).exportTransactions([_tx()], now);

    expect(result, ExportResult.failed);
  });
}