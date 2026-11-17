import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/recurring_rule.dart';
import '../../../data/models/transaction.dart';
import '../../../data/recurring/recurrence.dart';
import '../../../data/recurring/recurring_generator.dart';
import '../../../data/repositories/drift_recurring_rule_repository.dart';
import '../../../data/repositories/recurring_rule_repository.dart';
import '../../sync/application/sync_provider.dart';
import '../../transactions/application/transactions_provider.dart';
import '../../alerts/application/alert_provider.dart';

final recurringRuleRepositoryProvider = Provider<RecurringRuleRepository>(
  (ref) => DriftRecurringRuleRepository(ref.watch(databaseProvider)),
);

/// Creates the transactions that are due. A function so tests can replace it.
final dueGeneratorProvider = Provider<Future<int> Function(DateTime)>(
  (ref) => RecurringGenerator(ref.watch(databaseProvider)).generateDue,
);

class RecurringRunner {
  RecurringRunner(this._ref);

  final Ref _ref;
  Future<int>? _running;

  /// Creates everything that is due. Calls made while a run is in progress
  /// share it, so the same occurrence can never be inserted twice.
  Future<int> run() =>
      _running ??= _generate().whenComplete(() => _running = null);

  Future<int> _generate() async {
    final generate = _ref.read(dueGeneratorProvider);
    final created = await generate(DateTime.now());
    if (created > 0) {
      await _ref.read(transactionsProvider.notifier).reload();
      _ref.read(syncControllerProvider.notifier).requestSync();
      _ref.read(alertControllerProvider).check();
    }
    return created;
  }
}

final recurringRunnerProvider = Provider<RecurringRunner>(
  (ref) => RecurringRunner(ref),
);

class RecurringRulesNotifier extends AsyncNotifier<List<RecurringRule>> {
  RecurringRuleRepository get _repo => ref.read(recurringRuleRepositoryProvider);

  @override
  Future<List<RecurringRule>> build() {
    return ref.watch(recurringRuleRepositoryProvider).getAll();
  }

  Future<void> create({
    required double amount,
    required TransactionType type,
    required String category,
    required String note,
    required Frequency frequency,
    required DateTime startDate,
  }) async {
    await _repo.add(
      RecurringRule(
        syncId: const Uuid().v4(),
        amount: amount,
        type: type,
        category: category,
        note: note,
        frequency: frequency,
        startDate: startDate,
      ),
    );
    state = AsyncData(await _repo.getAll());

    // Creates the first occurrence right away when it is already due.
    await ref.read(recurringRunnerProvider).run();
    ref.read(syncControllerProvider.notifier).requestSync();
  }

  Future<void> remove(String syncId) async {
    final current = state.value ?? [];
    state = AsyncData(current.where((r) => r.syncId != syncId).toList());
    await _repo.remove(syncId);
    ref.read(syncControllerProvider.notifier).requestSync();
  }

  /// Undo of a delete.
  Future<void> restore(RecurringRule rule) async {
    await _repo.add(rule);
    state = AsyncData(await _repo.getAll());
    ref.read(syncControllerProvider.notifier).requestSync();
  }
}

final recurringRulesProvider =
    AsyncNotifierProvider<RecurringRulesNotifier, List<RecurringRule>>(
  RecurringRulesNotifier.new,
);