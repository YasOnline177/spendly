import '../models/transaction.dart';

abstract class TransactionRepository {
  Future<List<AppTransaction>> getAll();
  Future<void> add(AppTransaction t);
  Future<void> remove(int id);
}