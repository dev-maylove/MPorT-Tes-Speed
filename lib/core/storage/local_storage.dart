import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local storage facade.
///
/// - Non-sensitive preferences (theme, units, flags) → SharedPreferences
/// - Sensitive values (tokens, secrets, if any) → FlutterSecureStorage
class LocalStorage {
  SharedPreferences? _prefs;

  /// flutter_secure_storage ≥11 API (no encryptedSharedPreferences).
  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: true,
      migrateOnAlgorithmChange: true,
      storageNamespace: 'mport_prefs',
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  Future<SharedPreferences> get _instance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ── SharedPreferences (non-sensitive) ──────────────────────────────

  Future<String?> getString(String key) async {
    final prefs = await _instance;
    return prefs.getString(key);
  }

  Future<bool> setString(String key, String value) async {
    final prefs = await _instance;
    return prefs.setString(key, value);
  }

  Future<bool> remove(String key) async {
    final prefs = await _instance;
    return prefs.remove(key);
  }

  Future<bool> clear() async {
    final prefs = await _instance;
    return prefs.clear();
  }

  Future<bool?> getBool(String key) async {
    final prefs = await _instance;
    return prefs.getBool(key);
  }

  Future<bool> setBool(String key, bool value) async {
    final prefs = await _instance;
    return prefs.setBool(key, value);
  }

  // ── Secure storage (sensitive) ─────────────────────────────────────

  Future<String?> getSecure(String key) => _secure.read(key: key);

  Future<void> setSecure(String key, String value) =>
      _secure.write(key: key, value: value);

  Future<void> removeSecure(String key) => _secure.delete(key: key);

  Future<void> clearSecure() => _secure.deleteAll();
}
