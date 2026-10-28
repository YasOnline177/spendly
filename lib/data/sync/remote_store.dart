class RemoteTransaction {
  final String syncId;
  final double amount;
  final String type;
  final String category;
  final String note;
  final int date; // milliseconds since epoch
  final int updatedAt; // milliseconds since epoch
  final bool deleted;

  const RemoteTransaction({
    required this.syncId,
    required this.amount,
    required this.type,
    required this.category,
    required this.note,
    required this.date,
    required this.updatedAt,
    required this.deleted,
  });
}

class RemoteBudget {
  final String category;
  final double monthlyLimit;
  final int updatedAt;
  final bool deleted;

  const RemoteBudget({
    required this.category,
    required this.monthlyLimit,
    required this.updatedAt,
    required this.deleted,
  });
}

abstract class RemoteStore {
  Future<List<RemoteTransaction>> fetchTransactions();
  Future<List<RemoteBudget>> fetchBudgets();
  Future<void> pushTransactions(List<RemoteTransaction> items);
  Future<void> pushBudgets(List<RemoteBudget> items);
}

/// A user-friendly sync error, safe to show on screen.
class SyncFailure implements Exception {
  final String message;
  const SyncFailure(this.message);

  @override
  String toString() => message;
}