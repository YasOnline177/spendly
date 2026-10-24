import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/transaction.dart';
import '../../../data/repositories/drift_transaction_repository.dart';
import '../../../data/repositories/transaction_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => DriftTransactionRepository(ref.watch(databaseProvider)),
);

class TransactionsNotifier extends Notifier<List<AppTransaction>> {
  TransactionRepository get _repo => ref.read(transactionRepositoryProvider);

  @override
  List<AppTransaction> build() {
    _load();
    return [];
  }

  Future<void> _load() async {
    state = await _repo.getAll();
  }

  Future<void> add(AppTransaction t) async {
    await _repo.add(t);
    await _load();
  }

  Future<void> remove(int id) async {
    // Update the UI immediately, then delete from the database.
    state = state.where((t) => t.id != id).toList();
    await _repo.remove(id);
  }
}

final transactionsProvider =
    NotifierProvider<TransactionsNotifier, List<AppTransaction>>(
  TransactionsNotifier.new,
);

class Summary {
  final double income;
  final double expense;
  const Summary({required this.income, required this.expense});
  double get balance => income - expense;
}

final summaryProvider = Provider<Summary>((ref) {
  final txs = ref.watch(transactionsProvider);
  double income = 0;
  double expense = 0;
  for (final t in txs) {
    if (t.type == TransactionType.income) {
      income += t.amount;
    } else {
      expense += t.amount;
    }
  }
  return Summary(income: income, expense: expense);
});