import 'package:flutter/material.dart';
import '../../../../core/utils/formatters.dart';
import '../../application/transactions_provider.dart';

class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key, required this.summary});
  final Summary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total balance',
            style: textTheme.labelLarge
                ?.copyWith(color: scheme.onPrimary.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 4),
          Text(
            currencyFmt.format(summary.balance),
            style: textTheme.headlineMedium?.copyWith(
              color: scheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Item(
                  icon: Icons.arrow_downward,
                  label: 'Income',
                  amount: summary.income,
                ),
              ),
              Expanded(
                child: _Item(
                  icon: Icons.arrow_upward,
                  label: 'Expenses',
                  amount: summary.expense,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.icon, required this.label, required this.amount});
  final IconData icon;
  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: scheme.onPrimary.withValues(alpha: 0.2),
          child: Icon(icon, size: 16, color: scheme.onPrimary),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: textTheme.labelSmall
                  ?.copyWith(color: scheme.onPrimary.withValues(alpha: 0.8)),
            ),
            Text(
              currencyFmt.format(amount),
              style: textTheme.labelLarge?.copyWith(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}