import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/categories.dart';
import '../../../data/models/transaction.dart';
import '../application/transactions_provider.dart';
import '../../../data/recurring/recurrence.dart';
import '../../recurring/application/recurring_provider.dart';

enum _Repeat { never, weekly, monthly }

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key, this.existing});

  /// When set, the screen edits this transaction instead of creating one.
  final AppTransaction? existing;

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  late TransactionType _type;
  late String _category;
  late DateTime _date;

  _Repeat _repeat = _Repeat.never;

  Frequency? get _frequency => switch (_repeat) {
    _Repeat.never => null,
    _Repeat.weekly => Frequency.weekly,
    _Repeat.monthly => Frequency.monthly,
  };

  String get _repeatHint {
    switch (_repeat) {
      case _Repeat.never:
        return '';
      case _Repeat.weekly:
        return 'Repeats every ${DateFormat('EEEE').format(_date)}.';
      case _Repeat.monthly:
        return _date.day > 28
            ? 'Repeats monthly on day ${_date.day} (the last day in shorter months).'
            : 'Repeats monthly on day ${_date.day}.';
    }
  }

  bool get _isEditing => widget.existing != null;

  List<CategoryInfo> get _categories =>
      _type == TransactionType.expense ? expenseCategories : incomeCategories;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? TransactionType.expense;
    _category = e?.category ?? expenseCategories.first.name;
    _date = e?.date ?? DateTime.now();
    _amountCtrl = TextEditingController(
      text: e == null ? '' : e.amount.toStringAsFixed(2),
    );
    _noteCtrl = TextEditingController(text: e?.note ?? '');
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: _repeat == _Repeat.never
          ? now
          : now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountCtrl.text);
    final note = _noteCtrl.text.trim();

    if (_frequency != null && !_isEditing) {
      // The rule creates the transactions (the first one right away if due).
      await ref
          .read(recurringRulesProvider.notifier)
          .create(
            amount: amount,
            type: _type,
            category: _category,
            note: note,
            frequency: _frequency!,
            startDate: _date,
          );
    } else {
      ref
          .read(transactionsProvider.notifier)
          .add(
            AppTransaction(
              id:
                  widget.existing?.id ??
                  0, // 0 = new, the database assigns an id
              amount: amount,
              type: _type,
              category: _category,
              note: note,
              date: _date,
            ),
          );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit transaction' : 'Add transaction'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text('Expense'),
                  icon: Icon(Icons.arrow_upward),
                ),
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text('Income'),
                  icon: Icon(Icons.arrow_downward),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                _category = _categories.first.name;
              }),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: 'LKR ',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter an amount';
                final n = double.tryParse(v);
                if (n == null || n <= 0) return 'Amount must be greater than 0';
                return null;
              },
            ),
            const SizedBox(height: 20),
            Text('Category', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _categories)
                  ChoiceChip(
                    avatar: Icon(c.icon, size: 18),
                    label: Text(c.name),
                    selected: _category == c.name,
                    onSelected: (_) => setState(() => _category = c.name),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(DateFormat('EEE, d MMM y').format(_date)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickDate,
            ),
            if (!_isEditing) ...[
              const SizedBox(height: 12),
              Text('Repeat', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<_Repeat>(
                segments: const [
                  ButtonSegment(value: _Repeat.never, label: Text('Never')),
                  ButtonSegment(value: _Repeat.weekly, label: Text('Weekly')),
                  ButtonSegment(value: _Repeat.monthly, label: Text('Monthly')),
                ],
                selected: {_repeat},
                onSelectionChanged: (s) => setState(() {
                  _repeat = s.first;
                  // The date picker only allows future dates for repeats.
                  if (_repeat == _Repeat.never &&
                      _date.isAfter(DateTime.now())) {
                    _date = DateTime.now();
                  }
                }),
              ),
              if (_repeat != _Repeat.never)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _repeatHint,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(_isEditing ? 'Save changes' : 'Save transaction'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
