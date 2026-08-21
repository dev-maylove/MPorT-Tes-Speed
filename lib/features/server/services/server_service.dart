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
      scheme: _selected.scheme,
      download: _selected.downloadPath,
      upload: _selected.uploadPath,
      ping: _selected.pingPath,
    );
  }

  Future<void> ensureLoaded() async {
    _servers = TestServer.catalog();
    if (_selected.id != 'haansiro') {
      _selected = TestServer.haansiro();
    }
    _applySelected();
  }

  Future<void> loadServers({bool autoNearest = true}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    _servers = TestServer.catalog();
    _selected = TestServer.haansiro();
    _applySelected();
    _loading = false;
    notifyListeners();
    if (autoNearest) await selectNearest(force: true);
  }

  Future<TestServer> selectNearest({bool force = false}) async {
    if (_autoDone && !force && _selected.latencyMs != null) return _selected;

    _probing = true;
    _error = null;
    notifyListeners();

    await ensureLoaded();
    final client = http.Client();
    try {
      final latency = await _probeLatency(client, _selected);
      final updated = _selected.copyWith(latencyMs: latency);
      _servers = [updated];
      _selected = updated;
      _applySelected();
      if (latency == null) {
        _error = 'Server HaaNSirO tidak merespons';
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

  Future<double?> _probeLatency(http.Client client, TestServer server) async {
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
