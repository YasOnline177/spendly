import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/transaction.dart';
import '../data/file_sharer.dart';
import 'csv_export.dart';

enum ExportResult { shared, empty, failed }

class ExportService {
  ExportService(this._sharer);

  final FileSharer _sharer;

  Future<ExportResult> exportTransactions(
    List<AppTransaction> transactions,
    DateTime now,
  ) async {
    if (transactions.isEmpty) return ExportResult.empty;

    try {
      await _sharer.shareTextFile(
        fileName: exportFileName(now),
        content: buildTransactionsCsv(transactions),
        mimeType: 'text/csv',
        subject: 'Spendly transactions',
      );
      return ExportResult.shared;
    } catch (e, st) {
      debugPrint('CSV export failed: $e\n$st');
      return ExportResult.failed;
    }
  }
}

final exportServiceProvider = Provider<ExportService>(
  (ref) => ExportService(SharePlusFileSharer()),
);