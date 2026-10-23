enum TransactionType { income, expense }

class AppTransaction {
  final int id; 
  final double amount;
  final TransactionType type;
  final String category;
  final String note;
  final DateTime date;

  const AppTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.category,
    required this.note,
    required this.date,
  });
}