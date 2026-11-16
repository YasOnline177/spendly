import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/categories.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/recurring_rule.dart';
import '../../../data/models/transaction.dart';
import '../../../data/recurring/recurrence.dart';
import '../application/recurring_provider.dart';

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(recurringRulesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Recurring')),
      body: rules.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Something went wrong: $e')),
        data: (list) => list.isEmpty
            ? const _EmptyRecurring()
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: list.length,
                itemBuilder: (_, i) => _RuleTile(rule: list[i]),
              ),
      ),
    );
  }
}

class _RuleTile extends ConsumerWidget {
  const _RuleTile({required this.rule});

  final RecurringRule rule;

  String get _schedule {
    switch (rule.frequency) {
      case Frequency.weekly:
        return 'Weekly on ${DateFormat('EEEE').format(rule.startDate)}';
      case Frequency.monthly:
        return 'Monthly on day ${rule.startDate.day}';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isIncome = rule.type == TransactionType.income;
    final next = nextOccurrence(rule.frequency, rule.startDate, DateTime.now());
    final cat = findCategory(rule.category);

    return Dismissible(
      key: ValueKey(rule.syncId),
      direction: DismissDirection.endToStart,
      background: Container(
        color: scheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Icons.delete, color: scheme.onErrorContainer),
      ),
      onDismissed: (_) {
        final notifier = ref.read(recurringRulesProvider.notifier);
        notifier.remove(rule.syncId);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: const Text('Recurring rule deleted'),
              persist: false,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () => notifier.restore(rule),
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
        title: Text(
          rule.note.isEmpty ? rule.category : '${rule.category} · ${rule.note}',
        ),
        subtitle: Text(
          '$_schedule · next ${DateFormat('d MMM').format(next)}',
        ),
        trailing: Text(
          '${isIncome ? '+' : '-'}${currencyFmt.format(rule.amount)}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isIncome ? Colors.green : scheme.error,
          ),
        ),
      ),
    );
  }
}

class _EmptyRecurring extends StatelessWidget {
  const _EmptyRecurring();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_repeat, size: 64, color: scheme.outline),
            const SizedBox(height: 12),
            const Text('No recurring transactions'),
            const SizedBox(height: 4),
            Text(
              'Choose Repeat when adding a transaction',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}