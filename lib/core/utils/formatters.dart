import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/transaction.dart';

class TransactionsNotifier extends Notifier<List<AppTransaction>> {
  @override
  List<AppTransaction> build() => [];

  void add(AppTransaction t) {
    state = [t, ...state]..sort((a, b) => b.date.compareTo(a.date));
  }

  void remove(int id) {
    state = state.where((t) => t.id != id).toList();
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