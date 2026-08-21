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
      download: _selected.downloadPath,
      upload: _selected.uploadPath,
    );
  }

  Future<void> ensureLoaded() async {
    if (_servers.isEmpty) {
      _servers = TestServer.catalog();
    }
    _applySelected();
  }

  /// Pilih server otomatis = latency terendah (sekali di awal, atau paksa).
  Future<TestServer> selectNearest({bool force = false}) async {
    if (_autoDone && !force && _selected.latencyMs != null) {
      return _selected;
    }

    _probing = true;
    _error = null;
    notifyListeners();

    await ensureLoaded();
    final client = http.Client();
    final measured = <TestServer>[];

    try {
      final futures = _servers.map((s) async {
        final ms = await _probeLatency(client, s.host);
        return s.copyWith(latencyMs: ms);
      });
      measured.addAll(await Future.wait(futures));
    } finally {
      client.close();
    }

    final alive = measured
        .where((s) => s.latencyMs != null && s.latencyMs! > 0)
        .toList()
      ..sort((a, b) => a.latencyMs!.compareTo(b.latencyMs!));

    if (alive.isEmpty) {
      _error = 'Tidak ada server yang merespons — pakai HaaNSirO';
      _servers = measured.isEmpty ? TestServer.catalog() : measured;
      _selected = TestServer.haansiro();
      _applySelected();
      _probing = false;
      _autoDone = true;
      notifyListeners();
      return _selected;
    }

    _servers = [
      ...alive,
      ...measured.where((s) => s.latencyMs == null),
    ];
    _selected = alive.first;
    _applySelected();
    _autoDone = true;
    _probing = false;
    notifyListeners();
    return _selected;
  }

  void select(TestServer server) {
    _selected = server;
    _applySelected();
    notifyListeners();
  }

  Future<void> loadServers({bool autoNearest = true}) async {
    _loading = true;
    _error = null;
    notifyListeners();

    _servers = TestServer.catalog();
    _selected = _servers.firstWhere(
      (s) => s.isDefault,
      orElse: () => _servers.first,
    );
    _applySelected();
    _loading = false;
    notifyListeners();

    if (autoNearest) {
      await selectNearest(force: true);
    }
  }

  Future<double?> _probeLatency(http.Client client, String host) async {
    final uri = Uri.parse(
      'https://$host/?ping=1&n=${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      final sw = Stopwatch()..start();
      final res = await client
          .head(uri, headers: ServerConfig.defaultHeaders)
          .timeout(const Duration(seconds: 4));
      sw.stop();
      if (res.statusCode < 500) return sw.elapsedMicroseconds / 1000.0;
    } catch (_) {}

    try {
      final sw = Stopwatch()..start();
      final res = await client
          .get(
            uri,
            headers: {
              ...ServerConfig.defaultHeaders,
              'Range': 'bytes=0-0',
            },
          )
          .timeout(const Duration(seconds: 4));
      sw.stop();
      if (res.statusCode < 500) return sw.elapsedMicroseconds / 1000.0;
    } catch (_) {}
    return null;
  }
}
