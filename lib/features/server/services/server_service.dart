import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/server_config.dart';
import '../../speed_test/models/test_server.dart';

class ServerService extends ChangeNotifier {
  ServerService._();
  static final ServerService instance = ServerService._();
  factory ServerService() => instance;

  static const cbnServersUrl = 'https://cbn.speedtestcustom.com/api/js/servers?engine=js&limit=100&https_functional=true';
  List<TestServer> _servers = TestServer.catalog();
  TestServer _selected = TestServer.haansiro();
  bool _loading = false, _probing = false, _autoDone = false;
  String? _error;

  List<TestServer> get servers => List.unmodifiable(_servers);
  TestServer get selected => _selected;
  bool get isLoading => _loading;
  bool get isProbing => _probing;
  bool get autoDone => _autoDone;
  String? get error => _error;

  void _applySelected() {
    if (_selected.engine == TestEngine.cbnSpeedtestCustom) return;
    ServerConfig.useServer(host: _selected.host, name: _selected.name,
      scheme: _selected.scheme, download: _selected.downloadPath,
      upload: _selected.uploadPath, ping: _selected.pingPath);
  }

  Future<void> ensureLoaded() async {
    if (_servers.length == 1) await loadCbnServers(autoNearest: false);
    _applySelected();
  }

  Future<void> loadCbnServers({bool autoNearest = true}) async {
    _loading = true; _error = null; notifyListeners();
    final base = <TestServer>[TestServer.haansiro()];
    try {
      final res = await http.get(Uri.parse(cbnServersUrl), headers: ServerConfig.defaultHeaders)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final data = jsonDecode(res.body);
      if (data is List) {
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            final s = TestServer.fromCbn(item);
            if (s.host.isNotEmpty && (item['status'] ?? 1) == 1) base.add(s);
          }
        }
      }
    } catch (e) { _error = 'Server CBN gagal dimuat: $e'; }
    final seen = <String>{};
    _servers = base.where((s) => seen.add(s.id)).toList();
    _selected = _servers.firstWhere((s) => s.isDefault, orElse: () => _servers.first);
    _autoDone = false;
    _applySelected();
    _loading = false;
    notifyListeners();
    if (autoNearest) await selectNearest(force: true);
  }

  Future<TestServer> selectNearest({bool force = false}) async {
    if (_autoDone && !force && _selected.latencyMs != null) return _selected;
    _probing = true; _error = null; notifyListeners();
    await ensureLoaded();
    final client = http.Client();
    try {
      final measured = await Future.wait(_servers.map((s) async {
        return s.copyWith(latencyMs: await _probeLatency(client, s));
      }));
      final alive = measured.where((s) => s.latencyMs != null && s.latencyMs! > 0).toList()
        ..sort((a,b) { final c=a.latencyMs!.compareTo(b.latencyMs!); return c != 0 ? c : (a.distanceKm ?? 999999).compareTo(b.distanceKm ?? 999999); });
      _servers = [...alive, ...measured.where((s) => s.latencyMs == null)];
      if (alive.isNotEmpty) { _selected = alive.first; _applySelected(); }
      else { _selected = TestServer.haansiro(); _applySelected(); _error = 'Tidak ada server yang merespons'; }
      _autoDone = true; return _selected;
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

  void select(TestServer server) { _selected=server; _applySelected(); notifyListeners(); }
  Future<void> loadServers({bool autoNearest=true}) => loadCbnServers(autoNearest:autoNearest);

  Future<double?> _probeLatency(http.Client client, TestServer server) async {
    final uri = Uri.parse('${server.scheme}://${server.host}/?mport_ping=${DateTime.now().microsecondsSinceEpoch}');
    try {
      final sw=Stopwatch()..start();
      final r=await client.head(uri,headers:ServerConfig.defaultHeaders).timeout(const Duration(seconds:4)); sw.stop();
      if(r.statusCode<500) return sw.elapsedMicroseconds/1000;
    } catch (_) {}
    try {
      final sw=Stopwatch()..start();
      final r=await client.get(uri,headers:{...ServerConfig.defaultHeaders,'Range':'bytes=0-0'}).timeout(const Duration(seconds:4)); sw.stop();
      if(r.statusCode<500) return sw.elapsedMicroseconds/1000;
    } catch (_) {}
    return null;
  }
}
