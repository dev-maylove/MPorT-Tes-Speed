import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/server_config.dart';
import '../../speed_test/models/test_server.dart';

class ServerService extends ChangeNotifier {
  ServerService._();
  static final ServerService instance = ServerService._();
  factory ServerService() => instance;

  List<TestServer> _servers = TestServer.catalog();
  TestServer _selected = TestServer.haansiro();
  bool _loading = false;
  bool _probing = false;
  bool _autoDone = false;
  String? _error;
  int _selectionGeneration = 0;

  List<TestServer> get servers => List.unmodifiable(_servers);
  TestServer get selected => _selected;
  bool get isLoading => _loading;
  bool get isProbing => _probing;
  bool get autoDone => _autoDone;
  String? get error => _error;

  void _applySelected() {
    ServerConfig.useServer(
      host: _selected.host,
      name: _selected.name,
      scheme: _selected.scheme,
      download: _selected.downloadPath,
      upload: _selected.uploadPath,
      ping: _selected.pingPath,
    );
  }

  Future<void> ensureLoaded() async {
    if (_servers.isEmpty) {
      _servers = TestServer.catalog();
    }
    _applySelected();
  }

  Future<void> loadServers({bool autoNearest = true}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    _servers = TestServer.catalog();
    final match = _servers.where((s) => s.id == _selected.id);
    if (match.isNotEmpty) {
      _selected = match.first;
    } else {
      _selected = TestServer.haansiro();
    }
    _applySelected();
    _loading = false;
    notifyListeners();
    if (autoNearest) await selectNearest(force: true);
  }

  /// Pilih server latency terendah.
  /// Strategi cepat:
  /// 1) Urutkan by jarak
  /// 2) Probe paralel batch kecil (4 sekaligus)
  /// 3) 2 sampel per server, ambil minimum
  /// 4) Early-stop if latency < 12 ms
  Future<TestServer> selectNearest({bool force = false}) async {
    if (_autoDone && !force && _selected.latencyMs != null) return _selected;
    final generation = ++_selectionGeneration;

    _probing = true;
    _error = null;
    notifyListeners();

    await ensureLoaded();

    try {
      final ordered = List<TestServer>.from(_servers)
        ..sort((a, b) {
          final d = (a.distanceKm ?? 999).compareTo(b.distanceKm ?? 999);
          if (d != 0) return d;
          // Prioritas HaanSirO di jarak sama
          if (a.isDefault) return -1;
          if (b.isDefault) return 1;
          return 0;
        });

      // Cukup probe 10 terdekat — lebih cepat, hasil tetap akurat
      final toProbe = ordered.take(10).toList();

      TestServer? best;
      double bestLat = double.infinity;

      // Batch paralel 4 server
      const batchSize = 4;
      for (var i = 0; i < toProbe.length; i += batchSize) {
        final batch = toProbe.skip(i).take(batchSize).toList();
        final results = await Future.wait(
          batch.map((s) async {
            final lat = await _probeLatencyFast(s);
            return MapEntry(s, lat);
          }),
        );

        if (generation != _selectionGeneration) return _selected;

        for (final e in results) {
          final s = e.key;
          final lat = e.value;
          if (lat == null) continue;

          final idx = _servers.indexWhere((x) => x.id == s.id);
          if (idx >= 0) {
            _servers[idx] = s.copyWith(latencyMs: lat);
          }

          if (lat < bestLat) {
            bestLat = lat;
            final updated = s.copyWith(latencyMs: lat);
            best = updated;
            // Update UI immediately so the user sees the selected server
            _selected = updated;
            _applySelected();
            notifyListeners();
          }
        }

        // Early stop: latency is very good → no need to probe the rest
        if (bestLat < 12) break;
      }

      _servers = List<TestServer>.from(_servers)
        ..sort((a, b) {
          final la = a.latencyMs ?? 99999.0;
          final lb = b.latencyMs ?? 99999.0;
          final c = la.compareTo(lb);
          if (c != 0) return c;
          return (a.distanceKm ?? 999).compareTo(b.distanceKm ?? 999);
        });

      if (generation != _selectionGeneration) return _selected;

      final chosen = best;
      if (chosen != null) {
        _selected = chosen;
        _applySelected();
      } else {
        // Fallback default
        _selected = TestServer.haansiro();
        _applySelected();
        _error = 'Probe failed — using default server';
      }

      _autoDone = true;
      return _selected;
    } catch (e) {
      _error = 'Server probe failed: $e';
      _autoDone = false;
      return _selected;
    } finally {
      if (generation == _selectionGeneration) {
        _probing = false;
        notifyListeners();
      }
    }
  }

  void select(TestServer server) {
    _selectionGeneration++;
    _autoDone = true;
    _selected = server;
    _applySelected();
    notifyListeners();
  }

  /// Select a server for an active speed test without triggering UI metadata
  /// work. The normal [select] method remains user-facing and notifies.
  void selectForTest(TestServer server) {
    _selectionGeneration++;
    _autoDone = true;
    _selected = server;
    _applySelected();
  }

  /// Abort an in-flight nearest-server probe before a speed test starts.
  void cancelProbe() {
    _selectionGeneration++;
    _probing = false;
    notifyListeners();
  }

  /// Probe cepat: HEAD dulu, fallback GET latency.txt
  /// 2 sampel → ambil minimum (abaikan cold-start TLS/TCP)
  Future<double?> _probeLatencyFast(TestServer server) async {
    final base = '${server.scheme}://${server.host}';
    final paths = <String>[
      if (server.pingPath.isNotEmpty) server.pingPath,
      '/speedtest/latency.txt',
      '/',
    ];

    final samples = <double>[];

    for (var attempt = 0; attempt < 2; attempt++) {
      for (final path in paths) {
        final ms = await _oneShot(base, path);
        if (ms != null) {
          samples.add(ms);
          break; // path ini OK, lanjut sampel berikutnya
        }
      }
      if (attempt == 0 && samples.isNotEmpty) {
        // very short pause between samples
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }

    if (samples.isEmpty) return null;
    return samples.reduce(math.min);
  }

  Future<double?> _oneShot(String base, String path) async {
    final url = '$base$path';
    final uri = Uri.parse(
      '$url${url.contains('?') ? '&' : '?'}n=${DateTime.now().microsecondsSinceEpoch}',
    );

    // HEAD lebih ringan
    try {
      final sw = Stopwatch()..start();
      final r = await http
          .head(uri, headers: {
            ...ServerConfig.defaultHeaders,
            'Connection': 'close',
          })
          .timeout(const Duration(milliseconds: 1500));
      sw.stop();
      if (r.statusCode >= 200 && r.statusCode < 400) {
        return sw.elapsedMicroseconds / 1000.0;
      }
    } catch (_) {}

    // Fallback GET (latency.txt biasanya 1 baris)
    try {
      final sw = Stopwatch()..start();
      final r = await http
          .get(uri, headers: {
            ...ServerConfig.defaultHeaders,
            'Connection': 'close',
          })
          .timeout(const Duration(milliseconds: 1500));
      sw.stop();
      if (r.statusCode >= 200 && r.statusCode < 400) {
        return sw.elapsedMicroseconds / 1000.0;
      }
    } catch (_) {}

    return null;
  }
}
