import '../models/recurring_rule.dart';

abstract class RecurringRuleRepository {
  Future<List<RecurringRule>> getAll();

  /// Creates the rule, or replaces/restores one with the same syncId.
  Future<void> add(RecurringRule rule);

  Future<void> remove(String syncId);
}