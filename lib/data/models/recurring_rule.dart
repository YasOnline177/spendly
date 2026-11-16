import '../recurring/recurrence.dart';
import 'transaction.dart';

class RecurringRule {
  final String syncId;
  final double amount;
  final TransactionType type;
  final String category;
  final String note;
  final Frequency frequency;
  final DateTime startDate;

  const RecurringRule({
    required this.syncId,
    required this.amount,
    required this.type,
    required this.category,
    required this.note,
    required this.frequency,
    required this.startDate,
  });
}