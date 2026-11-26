import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../budgets/application/budgets_provider.dart';
import '../data/alert_store.dart';
import '../data/notification_service.dart';
import 'alert_logic.dart';

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => LocalNotificationService(),
);

final alertStoreProvider = Provider<AlertStore>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  return SharedPreferencesAlertStore(uid ?? 'guest');
});

class AlertController {
  AlertController(this._ref);

  final Ref _ref;

  /// Sends any alerts that are due. Never throws: a notification problem
  /// must not get in the way of saving a transaction.
  Future<void> check() async {
    try {
      final store = _ref.read(alertStoreProvider);
      if (!await store.isEnabled()) return;

      final now = DateTime.now();
      final month = DateTime(now.year, now.month);
      final sent = await store.sentKeys();

      final alerts = planAlerts(
        progress: _ref.read(budgetProgressProvider),
        alreadySent: sent,
        month: month,
      );
      if (alerts.isEmpty) return;

      // Keep only this month's records, so old months don't pile up.
      final prefix = monthPrefix(month);
      final recorded = sent.where((k) => k.startsWith(prefix)).toSet();

      final service = _ref.read(notificationServiceProvider);
      for (final alert in alerts) {
        final message = alertMessage(alert);
        final delivered = await service.show(
          id: alert.notificationId,
          title: message.title,
          body: message.body,
        );
        if (delivered) recorded.addAll(alert.keys);
      }
      await store.saveSentKeys(recorded);
    } catch (e, st) {
      debugPrint('Budget alert check failed: $e\n$st');
    }
  }
}

final alertControllerProvider = Provider<AlertController>(
  (ref) => AlertController(ref),
);

class AlertSettingsNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref.watch(alertStoreProvider).isEnabled();

  /// Returns false when alerts were turned on but the phone blocks
  /// notifications for the app.
  Future<bool> setEnabled(bool enabled) async {
    await ref.read(alertStoreProvider).setEnabled(enabled);
    state = AsyncData(enabled);
    if (!enabled) return true;
    return _requestPermission();
  }

  /// Asks for the system permission the first time a budget is saved.
  /// Only remembers that it asked if the request really went through.
  Future<void> askPermissionOnce() async {
    if (!await future) return;
    final store = ref.read(alertStoreProvider);
    if (await store.permissionAsked()) return;

    try {
      await ref.read(notificationServiceProvider).requestPermission();
      await store.setPermissionAsked();
    } catch (e, st) {
      debugPrint('Notification permission request failed: $e\n$st');
    }
  }

  /// Shows a notification right now. Returns null on success, otherwise a
  /// message explaining what went wrong.

  Future<bool> _requestPermission() async {
    try {
      return await ref.read(notificationServiceProvider).requestPermission();
    } catch (e, st) {
      debugPrint('Notification permission request failed: $e\n$st');
      return false;
    }
  }
}

final alertSettingsProvider =
    AsyncNotifierProvider<AlertSettingsNotifier, bool>(
      AlertSettingsNotifier.new,
    );
