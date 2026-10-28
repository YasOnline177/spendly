import 'package:spendly_android/data/sync/remote_store.dart';

/// An in-memory stand-in for Firestore, shared between "devices" in tests.
class FakeRemoteStore implements RemoteStore {
  final transactions = <String, RemoteTransaction>{};
  final budgets = <String, RemoteBudget>{};
  int pushedTransactions = 0;
  int pushedBudgets = 0;

  @override
  Future<List<RemoteTransaction>> fetchTransactions() async =>
      transactions.values.toList();

  @override
  Future<List<RemoteBudget>> fetchBudgets() async => budgets.values.toList();

  @override
  Future<void> pushTransactions(List<RemoteTransaction> items) async {
    for (final t in items) {
      transactions[t.syncId] = t;
      pushedTransactions++;
    }
  }

  @override
  Future<void> pushBudgets(List<RemoteBudget> items) async {
    for (final b in items) {
      budgets[b.category] = b;
      pushedBudgets++;
    }
  }
}