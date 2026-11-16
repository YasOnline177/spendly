import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/categories.dart';
import '../../../../data/models/transaction.dart';
import '../../application/transaction_filter.dart';
import '../../application/transaction_filter_provider.dart';

enum _TypeChoice { all, expense, income }

/// Every category once ("Other" exists for both income and expense).
final _allCategories = {
  for (final c in [...expenseCategories, ...incomeCategories]) c.name: c,
}.values.toList();

const _sortLabels = {
  SortOption.newest: 'Newest',
  SortOption.oldest: 'Oldest',
  SortOption.highest: 'Highest amount',
  SortOption.lowest: 'Lowest amount',
};

Future<void> showTransactionFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _FilterSheet(),
  );
}

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late TransactionFilter _draft;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(transactionFilterProvider);
  }

  _TypeChoice get _typeChoice => switch (_draft.type) {
        null => _TypeChoice.all,
        TransactionType.expense => _TypeChoice.expense,
        TransactionType.income => _TypeChoice.income,
      };

  void _setType(_TypeChoice choice) {
    setState(() {
      _draft = switch (choice) {
        _TypeChoice.all => _draft.copyWith(clearType: true),
        _TypeChoice.expense => _draft.copyWith(type: TransactionType.expense),
        _TypeChoice.income => _draft.copyWith(type: TransactionType.income),
      };
    });
  }

  void _toggleCategory(String name, bool selected) {
    final next = {..._draft.categories};
    selected ? next.add(name) : next.remove(name);
    setState(() => _draft = _draft.copyWith(categories: next));
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _draft.from != null && _draft.to != null
          ? DateTimeRange(start: _draft.from!, end: _draft.to!)
          : null,
    );
    if (picked != null) {
      setState(() => _draft = _draft.copyWith(from: picked.start, to: picked.end));
    }
  }

  void _apply() {
    ref.read(transactionFilterProvider.notifier).set(_draft);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dateFmt = DateFormat('d MMM y');
    final hasDates = _draft.from != null && _draft.to != null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filters', style: textTheme.titleLarge),
            const SizedBox(height: 16),
            SegmentedButton<_TypeChoice>(
              segments: const [
                ButtonSegment(value: _TypeChoice.all, label: Text('All')),
                ButtonSegment(
                  value: _TypeChoice.expense,
                  label: Text('Expense'),
                ),
                ButtonSegment(value: _TypeChoice.income, label: Text('Income')),
              ],
              selected: {_typeChoice},
              onSelectionChanged: (s) => _setType(s.first),
            ),
            const SizedBox(height: 20),
            Text('Categories', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _allCategories)
                  FilterChip(
                    avatar: Icon(c.icon, size: 18),
                    label: Text(c.name),
                    selected: _draft.categories.contains(c.name),
                    onSelected: (on) => _toggleCategory(c.name, on),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Date range', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(
                    hasDates
                        ? '${dateFmt.format(_draft.from!)} – ${dateFmt.format(_draft.to!)}'
                        : 'Any date',
                  ),
                ),
                if (hasDates)
                  IconButton(
                    tooltip: 'Clear dates',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(
                      () => _draft = _draft.copyWith(clearDates: true),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Sort by', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in SortOption.values)
                  ChoiceChip(
                    label: Text(_sortLabels[option]!),
                    selected: _draft.sort == option,
                    onSelected: (_) => setState(
                      () => _draft = _draft.copyWith(sort: option),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(
                    () => _draft = TransactionFilter(query: _draft.query),
                  ),
                  child: const Text('Reset'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _apply,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('Show results'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}