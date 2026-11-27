import 'package:shared_preferences/shared_preferences.dart';

/// Device-local alert state: the on/off switch and which alerts were sent.
abstract class AlertStore {
  Future<bool> isEnabled();
  Future<void> setEnabled(bool value);
  Future<Set<String>> sentKeys();
  Future<void> saveSentKeys(Set<String> keys);
  Future<bool> permissionAsked();
  Future<void> setPermissionAsked();
}

class SharedPreferencesAlertStore implements AlertStore {
  SharedPreferencesAlertStore(this._userId, {SharedPreferencesAsync? prefs})
      : _prefs = prefs ?? SharedPreferencesAsync();

  final String _userId;
  final SharedPreferencesAsync _prefs;

  String get _enabledKey => 'budget_alerts_enabled_$_userId';
  String get _sentKey => 'budget_alerts_sent_$_userId';
  String get _askedKey => 'budget_alerts_permission_asked_$_userId';

  @override
  Future<bool> isEnabled() async => await _prefs.getBool(_enabledKey) ?? true;

  @override
  Future<void> setEnabled(bool value) => _prefs.setBool(_enabledKey, value);

  @override
  Future<Set<String>> sentKeys() async =>
      (await _prefs.getStringList(_sentKey) ?? const <String>[]).toSet();

  @override
  Future<void> saveSentKeys(Set<String> keys) =>
      _prefs.setStringList(_sentKey, keys.toList());

  @override
  Future<bool> permissionAsked() async =>
      await _prefs.getBool(_askedKey) ?? false;

  @override
  Future<void> setPermissionAsked() => _prefs.setBool(_askedKey, true);
}