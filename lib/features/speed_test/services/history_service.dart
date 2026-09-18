import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists speed-test results in encrypted storage (max 50 entries).
///
/// Uses [FlutterSecureStorage] (Android Keystore / iOS Keychain backed).
/// On first run after upgrade, migrates any legacy SharedPreferences history
/// into secure storage and deletes the plaintext copy.
///
/// Writes are serialized so concurrent add/remove/clear cannot interleave
/// read-modify-write sequences and drop entries.
class HistoryService {
  static const String _key = 'speed_test_history_v3_secure';
  static const String _legacyKeyV2 = 'speed_test_history_v2';
  static const String _legacyKeyV1 = 'speed_test_history';
  static const int maxItems = 50;

  /// flutter_secure_storage ≥11: encryptedSharedPreferences removed.
  /// Default ciphers are RSA-OAEP + AES-GCM with migrateOnAlgorithmChange.
  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: true,
      migrateOnAlgorithmChange: true,
      storageNamespace: 'mport_history',
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Simple chain lock: each mutating call waits for the previous one.
  Future<void> _writeChain = Future<void>.value();
  bool _migrated = false;

  Future<T> _serialized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _writeChain = _writeChain.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<void> _ensureMigrated() async {
    if (_migrated) return;
    _migrated = true;
    try {
      final existing = await _secure.read(key: _key);
      if (existing != null && existing.isNotEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      var data = prefs.getStringList(_legacyKeyV2);
      if (data == null || data.isEmpty) {
        data = prefs.getStringList(_legacyKeyV1) ?? [];
      }
      if (data.isEmpty) return;

      // Migrate plaintext history → encrypted storage
      await _secure.write(key: _key, value: jsonEncode(data));
      await prefs.remove(_legacyKeyV2);
      await prefs.remove(_legacyKeyV1);
    } catch (_) {
      // Soft-fail: keep going with empty history if migration fails
    }
  }

  Future<List<Map<String, dynamic>>> getHistory() async {
    try {
      await _ensureMigrated();
      final raw = await _secure.read(key: _key);
      if (raw == null || raw.isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      final result = <Map<String, dynamic>>[];
      for (final item in decoded) {
        try {
          if (item is String) {
            final map = jsonDecode(item);
            if (map is Map) {
              result.add(Map<String, dynamic>.from(map));
            }
          } else if (item is Map) {
            result.add(Map<String, dynamic>.from(item));
          }
        } catch (_) {
          // skip corrupt entry
        }
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  Future<void> addResult({
    required double ping,
    required double jitter,
    double avgPing = 0,
    double maxPing = 0,
    double packetLossPercent = 0,
    required double download,
    required double upload,
    required String server,
    required DateTime timestamp,
    String? isp,
    String? networkName,
    String? connectionKind,
    String? deviceModel,
    String? testId,
    String? serverLocation,
  }) {
    return _serialized(() async {
      await _ensureMigrated();
      final history = await getHistory();

      history.insert(0, {
        'id': testId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'ping': ping,
        'jitter': jitter,
        'avgPing': avgPing,
        'maxPing': maxPing,
        'packetLossPercent': packetLossPercent,
        'download': download,
        'upload': upload,
        'server': server,
        'serverLocation': serverLocation ?? '',
        'timestamp': timestamp.toIso8601String(),
        'isp': isp ?? '',
        'networkName': networkName ?? '',
        'connectionKind': connectionKind ?? '',
        'deviceModel': deviceModel ?? '',
        'testId': testId ?? '',
      });

      final limited = history.take(maxItems).toList();
      await _secure.write(key: _key, value: jsonEncode(limited));
    });
  }

  Future<void> removeAt(int index) {
    return _serialized(() async {
      await _ensureMigrated();
      final history = await getHistory();
      if (index < 0 || index >= history.length) return;
      history.removeAt(index);
      await _secure.write(key: _key, value: jsonEncode(history));
    });
  }

  Future<void> removeById(String id) {
    return _serialized(() async {
      await _ensureMigrated();
      final history = await getHistory();
      history.removeWhere(
        (e) => (e['id']?.toString() ?? e['testId']?.toString() ?? '') == id,
      );
      await _secure.write(key: _key, value: jsonEncode(history));
    });
  }

  Future<void> clearHistory() {
    return _serialized(() async {
      await _secure.delete(key: _key);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_legacyKeyV2);
        await prefs.remove(_legacyKeyV1);
      } catch (_) {}
    });
  }
}
