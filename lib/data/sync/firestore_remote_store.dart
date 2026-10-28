import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'remote_store.dart';

class FirestoreRemoteStore implements RemoteStore {
  FirestoreRemoteStore(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;

  static const _batchSize = 400; // Firestore allows 500 writes per batch
  static const _timeout = Duration(seconds: 20);

  CollectionReference<Map<String, dynamic>> get _transactions =>
      _db.collection('users').doc(_uid).collection('transactions');

  CollectionReference<Map<String, dynamic>> get _budgets =>
      _db.collection('users').doc(_uid).collection('budgets');

  @override
  Future<List<RemoteTransaction>> fetchTransactions() {
    return _run(() async {
      // Source.server fails fast when offline instead of returning stale cache.
      final snap =
          await _transactions.get(const GetOptions(source: Source.server));
      return snap.docs.map((d) {
        final m = d.data();
        return RemoteTransaction(
          syncId: d.id,
          amount: (m['amount'] as num).toDouble(),
          type: m['type'] as String,
          category: m['category'] as String,
          note: (m['note'] as String?) ?? '',
          date: (m['date'] as num).toInt(),
          updatedAt: (m['updatedAt'] as num).toInt(),
          deleted: (m['deleted'] as bool?) ?? false,
        );
      }).toList();
    });
  }

  @override
  Future<List<RemoteBudget>> fetchBudgets() {
    return _run(() async {
      final snap = await _budgets.get(const GetOptions(source: Source.server));
      return snap.docs.map((d) {
        final m = d.data();
        return RemoteBudget(
          category: d.id,
          monthlyLimit: (m['monthlyLimit'] as num).toDouble(),
          updatedAt: (m['updatedAt'] as num).toInt(),
          deleted: (m['deleted'] as bool?) ?? false,
        );
      }).toList();
    });
  }

  @override
  Future<void> pushTransactions(List<RemoteTransaction> items) {
    return _run(() async {
      for (var i = 0; i < items.length; i += _batchSize) {
        final chunk = items.sublist(i, min(i + _batchSize, items.length));
        final batch = _db.batch();
        for (final t in chunk) {
          batch.set(_transactions.doc(t.syncId), {
            'amount': t.amount,
            'type': t.type,
            'category': t.category,
            'note': t.note,
            'date': t.date,
            'updatedAt': t.updatedAt,
            'deleted': t.deleted,
          });
        }
        await batch.commit();
      }
    });
  }

  @override
  Future<void> pushBudgets(List<RemoteBudget> items) {
    return _run(() async {
      for (var i = 0; i < items.length; i += _batchSize) {
        final chunk = items.sublist(i, min(i + _batchSize, items.length));
        final batch = _db.batch();
        for (final b in chunk) {
          batch.set(_budgets.doc(b.category), {
            'monthlyLimit': b.monthlyLimit,
            'updatedAt': b.updatedAt,
            'deleted': b.deleted,
          });
        }
        await batch.commit();
      }
    });
  }

  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action().timeout(_timeout);
    } on TimeoutException {
      throw const SyncFailure('Sync timed out. Check your connection.');
    } on FirebaseException catch (e) {
      throw SyncFailure(_message(e.code));
    }
  }

  String _message(String code) {
    switch (code) {
      case 'permission-denied':
        return 'Cloud access denied. Make sure your email is verified.';
      case 'unavailable':
        return 'You appear to be offline. Changes will sync later.';
      default:
        return 'Sync failed. Please try again.';
    }
  }
}