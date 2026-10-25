import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../transactions/application/transactions_provider.dart';
import 'report_calculations.dart';

class SelectedMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void previous() => state = DateTime(state.year, state.month - 1);

  void next() {
    final now = DateTime.now();
    final candidate = DateTime(state.year, state.month + 1);
    if (!candidate.isAfter(DateTime(now.year, now.month))) {
      state = candidate;
    }
  }
}

final selectedMonthProvider =
    NotifierProvider<SelectedMonthNotifier, DateTime>(
  SelectedMonthNotifier.new,
);

final categoryTotalsProvider = Provider<Map<String, double>>((ref) {
  final txs = ref.watch(transactionsProvider);
  final month = ref.watch(selectedMonthProvider);
  return expenseByCategory(txs, month);
});

final monthlyTotalsProvider = Provider<List<MonthTotal>>((ref) {
  final txs = ref.watch(transactionsProvider);
  return lastMonths(txs, DateTime.now());
});