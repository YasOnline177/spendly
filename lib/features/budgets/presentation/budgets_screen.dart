import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/categories.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/budget.dart';
import '../application/budget_calculations.dart';
import '../application/budgets_provider.dart';
import '../../alerts/application/alert_provider.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(budgetProgressProvider);
    final alertsOn = ref.watch(alertSettingsProvider).value ?? true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Budget alerts',
            icon: Icon(
              alertsOn
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
            ),
            onSelected: (value) => value == 'toggle'
                ? _toggleAlerts(context, ref, !alertsOn)
                : _sendTest(context, ref),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'toggle',
                child: Text(alertsOn ? 'Turn alerts off' : 'Turn alerts on'),
              ),
              const PopupMenuItem(
                value: 'test',
                child: Text('Send a test notification'),
              ),
            ],
          ),
        ],
      ),
      body: progress.isEmpty
          ? const _EmptyBudgets()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, left: 4),
                  child: Text(
                    'This month · ${DateFormat('MMMM y').format(DateTime.now())}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                for (final p in progress) _BudgetCard(p: p),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'set_budget_fab',
        onPressed: () => showBudgetSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Set budget'),
      ),
    );
  }
}

class _BudgetCard extends ConsumerWidget {
  const _BudgetCard({required this.p});
  final BudgetProgress p;

  Color _barColor(ColorScheme s) {
    if (p.ratio > 1) return s.error;
    if (p.ratio >= 0.8) return Colors.orange;
    return s.primary;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final cat = findCategory(p.budget.category);
    final barColor = _barColor(scheme);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Dismissible(
          key: ValueKey(p.budget.category),
          direction: DismissDirection.endToStart,
          background: Container(
            color: scheme.errorContainer,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: Icon(Icons.delete, color: scheme.onErrorContainer),
          ),
          onDismissed: (_) {
            final notifier = ref.read(budgetsProvider.notifier);
            notifier.remove(p.budget.category);
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(
                SnackBar(
                  content: const Text('Budget deleted'),
                  persist: false,
                  duration: const Duration(seconds: 4),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () => notifier.upsert(p.budget),
                  ),
                ),
              );
          },
          child: Material(
            color: scheme.surfaceContainerLow,
            child: InkWell(
              onTap: () => showBudgetSheet(context, existing: p.budget),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: scheme.primaryContainer,
                          child: Icon(
                            cat.icon,
                            size: 18,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(p.budget.category, style: textTheme.titleMedium),
                        const Spacer(),
                        Text(
                          '${(p.ratio * 100).round()}%',
                          style: textTheme.titleSmall?.copyWith(
                            color: barColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: p.ratio.clamp(0.0, 1.0).toDouble(),
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(8),
                      color: barColor,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${currencyFmt.format(p.spent)} of ${currencyFmt.format(p.budget.limit)}',
                            style: textTheme.bodySmall,
                          ),
                        ),
                        Text(
                          p.isOver
                              ? 'Over by ${currencyFmt.format(-p.remaining)}'
                              : '${currencyFmt.format(p.remaining)} left',
                          style: textTheme.bodySmall?.copyWith(
                            color: p.isOver ? scheme.error : scheme.outline,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyBudgets extends StatelessWidget {
  const _EmptyBudgets();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.savings_outlined, size: 64, color: scheme.outline),
          const SizedBox(height: 12),
          const Text('No budgets yet'),
          const SizedBox(height: 4),
          Text(
            'Set a monthly limit for a category',
            style: TextStyle(color: scheme.outline),
          ),
        ],
      ),
    );
  }
}

Future<void> showBudgetSheet(BuildContext context, {Budget? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _BudgetSheet(existing: existing),
  );
}

class _BudgetSheet extends ConsumerStatefulWidget {
  const _BudgetSheet({this.existing});
  final Budget? existing;

  @override
  ConsumerState<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<_BudgetSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;
  late String _category;

  @override
  void initState() {
    super.initState();
    _category = widget.existing?.category ?? expenseCategories.first.name;
    _amountCtrl = TextEditingController(
      text: widget.existing == null
          ? ''
          : widget.existing!.limit.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    ref
        .read(budgetsProvider.notifier)
        .upsert(
          Budget(category: _category, limit: double.parse(_amountCtrl.text)),
        );
    ref.read(alertSettingsProvider.notifier).askPermissionOnce();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing == null ? 'Set budget' : 'Edit budget',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in expenseCategories)
                  ChoiceChip(
                    avatar: Icon(c.icon, size: 18),
                    label: Text(c.name),
                    selected: _category == c.name,
                    onSelected: (_) => setState(() => _category = c.name),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                labelText: 'Monthly limit',
                prefixText: 'LKR ',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter a limit';
                final n = double.tryParse(v);
                if (n == null || n <= 0) return 'Limit must be greater than 0';
                return null;
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Save budget'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _toggleAlerts(
  BuildContext context,
  WidgetRef ref,
  bool enable,
) async {
  final granted = await ref
      .read(alertSettingsProvider.notifier)
      .setEnabled(enable);
  if (!context.mounted) return;

  final message = !enable
      ? 'Budget alerts turned off'
      : granted
      ? 'You will be notified at 80% and 100% of a budget'
      : 'Alerts are on, but notifications are blocked. Allow them in your phone settings.';

  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<void> _sendTest(BuildContext context, WidgetRef ref) async {
  final ok =
      await ref.read(alertSettingsProvider.notifier).sendTestNotification();
  if (!context.mounted || ok) return;

  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      const SnackBar(
        content: Text(
          'Could not show a notification. Check that notifications are allowed for Spendly in your phone settings.',
        ),
      ),
    );
}