import '../../../data/models/transaction.dart';

enum SortOption { newest, oldest, highest, lowest }

class TransactionFilter {
  const TransactionFilter({
    this.query = '',
    this.type,
    this.categories = const {},
    this.from,
    this.to,
    this.sort = SortOption.newest,
  });

  final String query;
  final TransactionType? type; // null = both
  final Set<String> categories; // empty = all
  final DateTime? from;
  final DateTime? to;
  final SortOption sort;

  /// Anything other than the search text that differs from the defaults.
  bool get hasSheetFilters =>
      type != null ||
      categories.isNotEmpty ||
      from != null ||
      to != null ||
      sort != SortOption.newest;

  bool get isActive => hasSheetFilters || query.trim().isNotEmpty;

  TransactionFilter copyWith({
    String? query,
    TransactionType? type,
    bool clearType = false,
    Set<String>? categories,
    DateTime? from,
    DateTime? to,
    bool clearDates = false,
    SortOption? sort,
  }) {
    return TransactionFilter(
      query: query ?? this.query,
      type: clearType ? null : (type ?? this.type),
      categories: categories ?? this.categories,
      from: clearDates ? null : (from ?? this.from),
      to: clearDates ? null : (to ?? this.to),
      sort: sort ?? this.sort,
    );
  }
}

List<AppTransaction> applyFilter(
  List<AppTransaction> txs,
  TransactionFilter f,
) {
  final q = f.query.trim().toLowerCase();
  final from =
      f.from == null ? null : DateTime(f.from!.year, f.from!.month, f.from!.day);
  // Exclusive end: midnight after the chosen last day, so the whole day counts.
  final to = f.to == null
      ? null
      : DateTime(f.to!.year, f.to!.month, f.to!.day)
          .add(const Duration(days: 1));

  final result = txs.where((t) {
    if (f.type != null && t.type != f.type) return false;
    if (f.categories.isNotEmpty && !f.categories.contains(t.category)) {
      return false;
    }
    if (from != null && t.date.isBefore(from)) return false;
    if (to != null && !t.date.isBefore(to)) return false;
    if (q.isNotEmpty) {
      final haystack =
          '${t.category} ${t.note} ${t.amount.toStringAsFixed(2)}'.toLowerCase();
      if (!haystack.contains(q)) return false;
    }
    return true;
  }).toList();

  int byDateDesc(AppTransaction a, AppTransaction b) {
    final c = b.date.compareTo(a.date);
    return c != 0 ? c : b.id.compareTo(a.id);
  }

  switch (f.sort) {
    case SortOption.newest:
      result.sort(byDateDesc);
    case SortOption.oldest:
      result.sort((a, b) => byDateDesc(b, a));
    case SortOption.highest:
      result.sort((a, b) {
        final c = b.amount.compareTo(a.amount);
        return c != 0 ? c : byDateDesc(a, b);
      });
    case SortOption.lowest:
      result.sort((a, b) {
        final c = a.amount.compareTo(b.amount);
        return c != 0 ? c : byDateDesc(a, b);
      });
  }
  return result;
}