import 'package:flutter_local_notifications/flutter_local_notifications.dart';

abstract class NotificationService {
  /// Asks for the Android 13+ notification permission.
  Future<bool> requestPermission();

  /// Returns true if the notification was actually shown.
  Future<bool> show({
    required int id,
    required String title,
    required String body,
  });
}

class LocalNotificationService implements NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<bool?>? _initialized;

  Future<void> _ensureInitialized() async {
    try {
      _initialized ??= _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_spendly'),
        ),
      );
      await _initialized;
    } catch (_) {
      _initialized = null; // try again next time instead of failing forever
      rethrow;
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> requestPermission() async {
    await _ensureInitialized();
    return await _android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<bool> show({
    required int id,
    required String title,
    required String body,
  }) async {
    await _ensureInitialized();

    // Blocked by the user: report "not delivered" so it is retried later.
    if (await _android?.areNotificationsEnabled() == false) return false;

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'budget_alerts',
          'Budget alerts',
          channelDescription:
              'Tells you when a budget is almost used up or exceeded',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
    return true;
  }
}
