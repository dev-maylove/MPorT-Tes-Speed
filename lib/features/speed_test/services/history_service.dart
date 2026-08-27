import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists speed-test results locally (max 50 entries).
class HistoryService {
  static const String _key = 'speed_test_history_v2';
  static const int maxItems = 50;

  Future<List<Map<String, dynamic>>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Prefer v2; fall back to legacy key once.
      var data = prefs.getStringList(_key);
      if (data == null || data.isEmpty) {
        data = prefs.getStringList('speed_test_history') ?? [];
        if (data.isNotEmpty) {
          await prefs.setStringList(_key, data);
        }
      }

      final result = <Map<String, dynamic>>[];
      for (final item in data) {
        try {
          final map = jsonDecode(item);
          if (map is Map) {
            result.add(Map<String, dynamic>.from(map));
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
  }) async {
    final prefs = await SharedPreferences.getInstance();
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

    await prefs.setStringList(
      _key,
      limited.map(jsonEncode).toList(),
    );
  }

  Future<void> removeAt(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();
    if (index < 0 || index >= history.length) return;
    history.removeAt(index);
    await prefs.setStringList(
      _key,
      history.map(jsonEncode).toList(),
    );
  }

  Future<void> removeById(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();
    history.removeWhere(
      (e) => (e['id']?.toString() ?? e['testId']?.toString() ?? '') == id,
    );
    await prefs.setStringList(
      _key,
      history.map(jsonEncode).toList(),
    );
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove('speed_test_history');
  }
}
