import 'package:idara_tracking_app/core/local_storage/local_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether this handset accepts push notifications.
///
/// Local to the device, like the theme and the language — it says "this phone
/// does not buzz", not "this account gets no alerts". GPSWOX decides *which*
/// alerts push, per rule, and that is an account-wide server setting we do not
/// write to.
///
/// Enabled unless the operator says otherwise: a fresh install that stayed
/// silent because a default was wrong is a support call nobody can diagnose.
@lazySingleton
class NotificationPreference {
  const NotificationPreference(this._prefs);

  final SharedPreferences _prefs;

  bool get isEnabled =>
      _prefs.getBool(StorageKeys.notificationsEnabled) ?? true;

  Future<void> enable() =>
      _prefs.setBool(StorageKeys.notificationsEnabled, true);

  Future<void> disable() =>
      _prefs.setBool(StorageKeys.notificationsEnabled, false);
}
