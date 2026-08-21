import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/server_config.dart';
import '../../speed_test/models/test_server.dart';

class ServerService extends ChangeNotifier {
  ServerService._();
  static final ServerService instance = ServerService._();
  factory ServerService() => instance;

  static const cbnServersUrl =
      'https://cbn.speedtestcustom.com/api/js/servers?engine=js&limit=100&https_functional=true';

  List<TestServer> _servers = TestServer.catalog();
  TestServer _selected = TestServer.haansiro();
  bool _loading = false;
  bool _probing = false;
  bool _autoDone = false;
  bool _cbnFetchAttempted = false;
  Future<void>? _loadingFuture;
  String? _error;

  List<TestServer> get servers => List.unmodifiable(_servers);
  TestServer get selected => _selected;
  bool get isLoading => _loading;
  bool get isProbing => _probing;
  bool get autoDone => _autoDone;
  String? get error => _error;

  void _applySelected() {
    if (_selected.engine == TestEngine.cbnSpeedtestCustom) return;
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
    if (!_cbnFetchAttempted) {
      await loadCbnServers(autoNearest: false);
    }
    _applySelected();
  }

  Future<void> loadCbnServers({bool autoNearest = true}) async {
    // Hindari double-fetch paralel
    if (_loadingFuture != null) {
      await _loadingFuture;
      if (autoNearest) await selectNearest(force: true);
      return;
    }

    final done = _doLoadCbnServers();
    _loadingFuture = done;
    try {
      await done;
    } finally {
      _loadingFuture = null;
    }
    if (autoNearest) await selectNearest(force: true);
  }

  Future<void> _doLoadCbnServers() async {
    _loading = true;
    _error = null;
    notifyListeners();

    final base = <TestServer>[TestServer.haansiro()];
    try {
      final res = await http
          .get(Uri.parse(cbnServersUrl), headers: ServerConfig.defaultHeaders)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }

      // Parse sinkron di isolate UI — aman & cepat untuk ~100 item.
      // JANGAN pakai compute() mengembalikan List<TestServer>:
      // objek custom tidak bisa di-send antar isolate.
      final cbnList = parseCbnServersJson(res.body);
      base.addAll(cbnList);
    } catch (e) {
      _error = 'Server CBN gagal dimuat: $e';
    } finally {
      _cbnFetchAttempted = true;
    }

    final seen = <String>{};
    _servers = [
      for (final s in base)
        if (seen.add(s.id)) s,
    ];

    // Pertahankan pilihan user jika masih ada di list; else default HaaNSirO
    final currentId = _selected.id;
    _selected = _servers.firstWhere(
      (s) => s.id == currentId,
      orElse: () => _servers.firstWhere(
        (s) => s.isDefault,
        orElse: () => _servers.first,
      ),
    );
    _autoDone = false;
    _applySelected();
    _loading = false;
    notifyListeners();
  }

  Future<TestServer> selectNearest({bool force = false}) async {
    if (_autoDone && !force && _selected.latencyMs != null) return _selected;

    _probing = true;
    _error = null;
    notifyListeners();

    await ensureLoaded();
    final client = http.Client();
    try {
      // Batasi probe paralel agar tidak membanjiri jaringan (max 12 sekaligus)
      final measured = <TestServer>[];
      const batchSize = 12;
      for (var i = 0; i < _servers.length; i += batchSize) {
        final end = (i + batchSize).clamp(0, _servers.length);
        final batch = _servers.sublist(i, end);
        final part = await Future.wait(
          batch.map((s) async {
            return s.copyWith(latencyMs: await _probeLatency(client, s));
          }),
        );
        measured.addAll(part);
      }

      final alive = measured
          .where((s) => s.latencyMs != null && s.latencyMs! > 0)
          .toList()
        ..sort((a, b) {
          final byLat = a.latencyMs!.compareTo(b.latencyMs!);
          if (byLat != 0) return byLat;
          // Prioritas engine native MPorT (HaaNSirO) jika latency setara
          final eng = (a.engine == TestEngine.mport ? 0 : 1)
              .compareTo(b.engine == TestEngine.mport ? 0 : 1);
          if (eng != 0) return eng;
          return (a.distanceKm ?? 999999).compareTo(b.distanceKm ?? 999999);
        });

      _servers = [
        ...alive,
        ...measured.where((s) => s.latencyMs == null),
      ];

      if (alive.isNotEmpty) {
        _selected = alive.first;
        _applySelected();
      } else {
        _selected = TestServer.haansiro();
        _applySelected();
        _error = 'Tidak ada server yang merespons';
      }
      _autoDone = true;
      return _selected;
    } catch (e) {
      _error = 'Gagal menguji server: $e';
      _autoDone = false;
      return _selected;
    } finally {
      client.close();
      _probing = false;
      notifyListeners();
    }
  }

  void select(TestServer server) {
    _selected = server;
    _applySelected();
    notifyListeners();
  }

  Future<void> loadServers({bool autoNearest = true}) async {
    _cbnFetchAttempted = false; // force refresh
    await loadCbnServers(autoNearest: autoNearest);
  }

  Future<double?> _probeLatency(http.Client client, TestServer server) async {
    // CBN tidak di-probe native (mesin WebView). Jangan ikut auto-nearest
    // agar HaaNSirO tetap jadi pilihan default mesin utama.
    if (server.engine == TestEngine.cbnSpeedtestCustom) {
      return null;
    }

    final uri = Uri.parse(
      '${server.scheme}://${server.host}/?mport_ping=${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      final sw = Stopwatch()..start();
      final r = await client
          .head(uri, headers: ServerConfig.defaultHeaders)
          .timeout(const Duration(seconds: 4));
      sw.stop();
      if (r.statusCode < 500) return sw.elapsedMicroseconds / 1000.0;
    } catch (_) {}
    try {
      final sw = Stopwatch()..start();
      final r = await client
          .get(
            uri,
            headers: {
              ...ServerConfig.defaultHeaders,
              'Range': 'bytes=0-0',
            },
          )
          .timeout(const Duration(seconds: 4));
      sw.stop();
      if (r.statusCode < 500) return sw.elapsedMicroseconds / 1000.0;
    } catch (_) {}
    return null;
  }
}
