import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/categories.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/transaction.dart';
import '../../auth/application/auth_provider.dart';
import '../../sync/application/sync_provider.dart';
import '../application/transactions_provider.dart';
import 'add_transaction_screen.dart';
import 'widgets/summary_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txsAsync = ref.watch(transactionsProvider);
    final summary = ref.watch(summaryProvider);
    final sync = ref.watch(syncControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spendly'),
        actions: [
          IconButton(
            tooltip: 'Sync now',
            onPressed: sync.status == SyncStatus.syncing
                ? null
                : () => _syncNow(context, ref),
            icon: sync.status == SyncStatus.syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    sync.status == SyncStatus.error
                        ? Icons.sync_problem
                        : Icons.sync,
                  ),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmSignOut(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          const _SyncStatusLine(),
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
            child: txsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Something went wrong: $e')),
              data: (txs) => txs.isEmpty
                  ? const _EmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: txs.length,
                      itemBuilder: (context, i) => _TransactionTile(t: txs[i]),
                    ),
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
              persist: false,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () => ref.read(transactionsProvider.notifier).add(t),
              ),
            ),
          );
      },
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddTransactionScreen(existing: t)),
        ),
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

Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Sign out?'),
      content: const Text('You can sign back in anytime.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Sign out'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    await ref.read(authRepositoryProvider).signOut();
  }
}

Future<void> _syncNow(BuildContext context, WidgetRef ref) async {
  await ref.read(syncControllerProvider.notifier).syncNow();
  if (!context.mounted) return;

  final s = ref.read(syncControllerProvider);
  if (s.status == SyncStatus.error) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(s.error ?? 'Sync failed')));
  }
}

class _SyncStatusLine extends ConsumerWidget {
  const _SyncStatusLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(syncControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    String? text;
    var isError = false;
    switch (s.status) {
      case SyncStatus.syncing:
        text = 'Syncing…';
      case SyncStatus.error:
        text = s.error ?? 'Sync failed';
        isError = true;
      case SyncStatus.idle:
        if (s.lastSynced != null) {
          text = 'Synced at ${DateFormat.Hm().format(s.lastSynced!)}';
        }
    }
    if (text == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isError ? scheme.error : scheme.outline,
              ),
        ),
      ),
    );
  }
}