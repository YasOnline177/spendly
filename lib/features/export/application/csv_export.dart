import '../../../data/models/transaction.dart';

// Tells Excel the file is UTF-8, so non-English text shows correctly.
const _utf8Bom = '\uFEFF';

const csvHeader = ['Date', 'Type', 'Category', 'Amount', 'Note'];

/// All transactions as CSV text, oldest first.
String buildTransactionsCsv(List<AppTransaction> transactions) {
  final sorted = [...transactions]
    ..sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });

  final rows = <List<String>>[
    csvHeader,
    for (final t in sorted)
      [
        _isoDate(t.date),
        t.type == TransactionType.income ? 'Income' : 'Expense',
        t.category,
        t.amount.toStringAsFixed(2),
        t.note,
      ],
  ];

  final lines = rows.map((row) => row.map(escapeCsvField).join(','));
  return '$_utf8Bom${lines.join('\r\n')}\r\n';
}

/// Makes one value safe for a CSV file.
String escapeCsvField(String value) {
  var v = value;

  // Spreadsheets treat text starting with these characters as a formula.
  if (RegExp(r'^[=+\-@\t\r]').hasMatch(v)) {
    v = "'$v";
  }

  // Quote anything that would break the row, and double inner quotes.
  if (v.contains(RegExp(r'[",\r\n]'))) {
    v = '"${v.replaceAll('"', '""')}"';
  }
  return v;
}

String exportFileName(DateTime now) =>
    'spendly-transactions-${_isoDate(now)}.csv';

// Built by hand so it never depends on the phone's language settings.
String _isoDate(DateTime d) {
  final month = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$month-$day';
}