import 'package:spendly_android/features/alerts/data/alert_store.dart';
import 'package:spendly_android/features/alerts/data/notification_service.dart';

class FakeAlertStore implements AlertStore {
  bool enabled = true;
  bool asked = false;
  Set<String> sent = {};

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<void> setEnabled(bool value) async => enabled = value;

  @override
  Future<Set<String>> sentKeys() async => {...sent};

  @override
  Future<void> saveSentKeys(Set<String> keys) async => sent = {...keys};

  @override
  Future<bool> permissionAsked() async => asked;

  @override
  Future<void> setPermissionAsked() async => asked = true;
}

class FakeNotificationService implements NotificationService {
  bool deliver = true;
  bool permissionGranted = true;
  int permissionRequests = 0;
  int attempts = 0;
  final shown = <({int id, String title, String body})>[];

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<bool> show({
    required int id,
    required String title,
    required String body,
  }) async {
    attempts++;
    if (!deliver) return false;
    shown.add((id: id, title: title, body: body));
    return true;
  }
}