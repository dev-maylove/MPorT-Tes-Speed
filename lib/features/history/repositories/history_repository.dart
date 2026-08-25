import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/storage/local_storage.dart';
import '../../speed_test/models/speed_result.dart';
import '../models/history_item.dart';

/// Repository alternatif berbasis LocalStorage (struktur feature history).
/// Main UI uses HistoryService under speed_test/services.
class HistoryRepository extends ChangeNotifier {
  static const String _key = 'mport_speed_history_v2';
  final LocalStorage _storage;
  final List<HistoryItem> _items = [];
  bool _loaded = false;

  HistoryRepository({LocalStorage? storage})
      : _storage = storage ?? LocalStorage() {
    load();
  }

  List<HistoryItem> get items => List.unmodifiable(_items);
  bool get isLoaded => _loaded;

  Future<void> load() async {
    try {
      final raw = await _storage.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        _items
          ..clear()
          ..addAll(
            list.map((e) => HistoryItem.fromJson(e as Map<String, dynamic>)),
          );
      }
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  Future<void> addResult(SpeedResult result) async {
    _items.insert(
      0,
      HistoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        result: result,
      ),
    );
    if (_items.length > AppConstants.maxHistoryItems) {
      _items.removeRange(AppConstants.maxHistoryItems, _items.length);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _items.removeWhere((e) => e.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> clear() async {
    _items.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final encoded = jsonEncode(_items.map((e) => e.toJson()).toList());
      await _storage.setString(_key, encoded);
    } catch (_) {}
  }
}
