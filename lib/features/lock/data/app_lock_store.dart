import 'package:shared_preferences/shared_preferences.dart';

/// Remembers whether app lock is on. It belongs to the phone, not the account.
abstract class AppLockStore {
  Future<bool> isEnabled();
  Future<void> setEnabled(bool value);
}

class SharedPreferencesAppLockStore implements AppLockStore {
  SharedPreferencesAppLockStore({SharedPreferencesAsync? prefs})
      : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static const _key = 'app_lock_enabled';

  @override
  Future<bool> isEnabled() async => await _prefs.getBool(_key) ?? false;

  @override
  Future<void> setEnabled(bool value) => _prefs.setBool(_key, value);
}