import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/sync/firestore_remote_store.dart';
import '../../../data/sync/remote_store.dart';
import '../../../data/sync/sync_service.dart';
import '../../auth/application/auth_provider.dart';
import '../../budgets/application/budgets_provider.dart';
import '../../transactions/application/transactions_provider.dart';

/// The cloud, or null when nobody is signed in with a verified email.
final remoteStoreProvider = Provider<RemoteStore?>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  final verified = ref.watch(emailVerifiedProvider);
  if (uid == null || !verified) return null;
  return FirestoreRemoteStore(FirebaseFirestore.instance, uid);
});

final syncServiceProvider = Provider<SyncService?>((ref) {
  final remote = ref.watch(remoteStoreProvider);
  if (remote == null) return null;
  return SyncService(ref.watch(databaseProvider), remote);
});

enum SyncStatus { idle, syncing, error }

class SyncState {
  final SyncStatus status;
  final DateTime? lastSynced;
  final String? error;

  const SyncState({
    this.status = SyncStatus.idle,
    this.lastSynced,
    this.error,
  });
}

class SyncController extends Notifier<SyncState> {
  Timer? _debounce;
  bool _running = false;
  bool _runAgain = false;
  bool _disposed = false;

  @override
  SyncState build() {
    final service = ref.watch(syncServiceProvider);
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _debounce?.cancel();
    });

    // Sync once as soon as a verified user is available.
    if (service != null) Future.microtask(syncNow);
    return const SyncState();
  }

  /// Called after local changes. Waits 2 seconds so quick edits are batched.
  void requestSync() {
    if (ref.read(syncServiceProvider) == null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), syncNow);
  }

  Future<void> syncNow() async {
    final service = ref.read(syncServiceProvider);
    if (service == null || _disposed) return;
    if (_running) {
      _runAgain = true;
      return;
    }

    _running = true;
    state = SyncState(status: SyncStatus.syncing, lastSynced: state.lastSynced);

    try {
      await service.sync();
      if (_disposed) return;
      // Refresh what's on screen with whatever the sync brought in.
      await ref.read(transactionsProvider.notifier).reload();
      await ref.read(budgetsProvider.notifier).reload();
      state = SyncState(lastSynced: DateTime.now());
    } on SyncFailure catch (e) {
      if (!_disposed) {
        state = SyncState(
          status: SyncStatus.error,
          lastSynced: state.lastSynced,
          error: e.message,
        );
      }
    } catch (_) {
      if (!_disposed) {
        state = SyncState(
          status: SyncStatus.error,
          lastSynced: state.lastSynced,
          error: 'Sync failed. Please try again.',
        );
      }
    } finally {
      _running = false;
    }

    if (_runAgain && !_disposed) {
      _runAgain = false;
      await syncNow();
    }
  }
}

final syncControllerProvider =
    NotifierProvider<SyncController, SyncState>(SyncController.new);