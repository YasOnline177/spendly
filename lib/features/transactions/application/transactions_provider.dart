import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../data/models/transaction.dart';
import '../../../data/repositories/drift_transaction_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../auth/application/auth_provider.dart';
import '../../sync/application/sync_provider.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  final db = AppDatabase(userId: uid ?? 'guest');
  ref.onDispose(db.close);
  return db;
});

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => DriftTransactionRepository(ref.watch(databaseProvider)),
);

class TransactionsNotifier extends AsyncNotifier<List<AppTransaction>> {
  TransactionRepository get _repo => ref.read(transactionRepositoryProvider);

  @override
  Future<List<AppTransaction>> build() {
    // watch (not read): reload when the signed-in user, and so the database, changes
    return ref.watch(transactionRepositoryProvider).getAll();
  }

  /// Re-reads the database (used after a sync brings in remote changes).
  Future<void> reload() async {
    state = AsyncData(await _repo.getAll());
  }

  /// Adds a new transaction (id 0) or replaces an existing one (real id).
  Future<void> add(AppTransaction t) async {
    await _repo.add(t);
    state = AsyncData(await _repo.getAll());
    ref.read(syncControllerProvider.notifier).requestSync();
  }

  Future<void> remove(int id) async {
    // Update the UI immediately, then delete from the database.
    final current = state.value ?? [];
    state = AsyncData(current.where((t) => t.id != id).toList());
    await _repo.remove(id);
    ref.read(syncControllerProvider.notifier).requestSync();
  }
}

final transactionsProvider =
    AsyncNotifierProvider<TransactionsNotifier, List<AppTransaction>>(
      TransactionsNotifier.new,
    );

class Summary {
  final double income;
  final double expense;
  const Summary({required this.income, required this.expense});
  double get balance => income - expense;
}

final summaryProvider = Provider<Summary>((ref) {
  final txs = ref.watch(transactionsProvider).value ?? [];
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
