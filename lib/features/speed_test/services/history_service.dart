import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class HistoryService {
  static const String _key = 'speed_test_history';

  Future<List<Map<String, dynamic>>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getStringList(_key) ?? [];

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
    required double download,
    required double upload,
    required String server,
    required DateTime timestamp,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();

    history.insert(0, {
      'ping': ping,
      'jitter': jitter,
      'download': download,
      'upload': upload,
      'server': server,
      'timestamp': timestamp.toIso8601String(),
    });

    final limited = history.take(50).toList();

    await prefs.setStringList(
      _key,
      limited.map(jsonEncode).toList(),
    );
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
