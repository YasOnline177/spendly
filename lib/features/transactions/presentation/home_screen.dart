import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/categories.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/transaction.dart';
import '../application/transactions_provider.dart';
import 'add_transaction_screen.dart';
import 'widgets/summary_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txs = ref.watch(transactionsProvider);
    final summary = ref.watch(summaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Spendly')),
      body: Column(
        children: [
          SummaryCard(summary: summary),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Recent transactions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          Expanded(
            child: txs.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: txs.length,
                    itemBuilder: (context, i) => _TransactionTile(t: txs[i]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_transaction_fab',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }
}

class _TransactionTile extends ConsumerWidget {
  const _TransactionTile({required this.t});
  final AppTransaction t;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isIncome = t.type == TransactionType.income;
    final cat = findCategory(t.category);

    return Dismissible(
      key: ValueKey(t.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: scheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Icons.delete, color: scheme.onErrorContainer),
      ),
      onDismissed: (_) {
        ref.read(transactionsProvider.notifier).remove(t.id);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: const Text('Transaction deleted'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () =>
                    ref.read(transactionsProvider.notifier).add(t),
              ),
            ),
          );
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isIncome
              ? Colors.green.withValues(alpha: 0.15)
              : scheme.primaryContainer,
          child: Icon(
            cat.icon,
            color: isIncome ? Colors.green : scheme.onPrimaryContainer,
          ),
        ),
        title: Text(t.category),
        subtitle: Text(
          t.note.isEmpty
              ? DateFormat('d MMM').format(t.date)
              : '${t.note} • ${DateFormat('d MMM').format(t.date)}',
        ),
        trailing: Text(
          '${isIncome ? '+' : '-'}${currencyFmt.format(t.amount)}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isIncome ? Colors.green : scheme.error,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long, size: 64, color: scheme.outline),
          const SizedBox(height: 12),
          const Text('No transactions yet'),
          const SizedBox(height: 4),
          Text(
            'Tap Add to record your first one',
            style: TextStyle(color: scheme.outline),
          ),
        ],
      ),
    );
  }
}