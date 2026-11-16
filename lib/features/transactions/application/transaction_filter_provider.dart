import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/transaction.dart';
import 'transaction_filter.dart';
import 'transactions_provider.dart';

class TransactionFilterNotifier extends Notifier<TransactionFilter> {
  @override
  TransactionFilter build() => const TransactionFilter();

  void set(TransactionFilter filter) => state = filter;

  void setQuery(String query) => state = state.copyWith(query: query);

  void clear() => state = const TransactionFilter();
}

final transactionFilterProvider =
    NotifierProvider<TransactionFilterNotifier, TransactionFilter>(
  TransactionFilterNotifier.new,
);

/// The transaction list after search, filters and sorting.
/// Keeps the loading/error states of the underlying provider.
final filteredTransactionsProvider =
    Provider<AsyncValue<List<AppTransaction>>>((ref) {
  final filter = ref.watch(transactionFilterProvider);
  return ref
      .watch(transactionsProvider)
      .whenData((txs) => applyFilter(txs, filter));
});