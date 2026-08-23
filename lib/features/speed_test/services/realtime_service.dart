import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/constants/server_config.dart';

enum RealtimeStatus { disconnected, connecting, connected, error }

/// Koneksi WebSocket real-time ke server HaaNSirO.
///
/// Protokol ringan (JSON text):
/// - client → server: `{"type":"ping","t":<ms>}`
/// - server → client: `{"type":"pong","t":<ms>}` atau pesan status lain
///
/// If the WS endpoint is unavailable, the service stays safe (error status)
/// dan app lanjut memakai HTTP seperti biasa.
class RealtimeService extends ChangeNotifier {
  RealtimeService._();
  static final RealtimeService instance = RealtimeService._();
  factory RealtimeService() => instance;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  RealtimeStatus _status = RealtimeStatus.disconnected;
  double? _rttMs;
  String? _lastError;
  int _backoffSec = 2;
  bool _disposed = false;
  bool _manualClose = false;

  RealtimeStatus get status => _status;
  double? get rttMs => _rttMs;
  String? get lastError => _lastError;
  bool get isConnected => _status == RealtimeStatus.connected;

  Future<void> connect({String? url}) async {
    if (_disposed) return;
    _manualClose = false;
    await disconnect(reconnect: false);

    final wsUrl = url ?? ServerConfig.wsUrl;
    _status = RealtimeStatus.connecting;
    _lastError = null;
    notifyListeners();

    try {
      final uri = Uri.parse(wsUrl);
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready.timeout(const Duration(seconds: 6));

      _status = RealtimeStatus.connected;
      _backoffSec = 2;
      notifyListeners();

      _sub = _channel!.stream.listen(
        _onMessage,
        onError: (e) {
          _lastError = e.toString();
          _status = RealtimeStatus.error;
          notifyListeners();
          _scheduleReconnect();
        },
        onDone: () {
          _status = RealtimeStatus.disconnected;
          notifyListeners();
          _scheduleReconnect();
        },
        cancelOnError: true,
      );

      _startPingLoop();
    } catch (e) {
      _lastError = e.toString();
      _status = RealtimeStatus.error;
      notifyListeners();
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic data) {
    try {
      final raw = data is String ? data : data.toString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;

      final type = decoded['type']?.toString();
      if (type == 'pong') {
        final t = decoded['t'];
        if (t is num) {
          final now = DateTime.now().millisecondsSinceEpoch;
          _rttMs = (now - t.toInt()).toDouble();
          notifyListeners();
        }
      }
    } catch (_) {
      // abaikan payload non-JSON
    }
  }

  void _startPingLoop() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_channel == null || _status != RealtimeStatus.connected) return;
      try {
        final t = DateTime.now().millisecondsSinceEpoch;
        _channel!.sink.add(jsonEncode({'type': 'ping', 't': t}));
      } catch (_) {}
    });
  }

  void _scheduleReconnect() {
    if (_manualClose || _disposed) return;
    _reconnectTimer?.cancel();
    final wait = _backoffSec;
    _backoffSec = (_backoffSec * 2).clamp(2, 30);
    _reconnectTimer = Timer(Duration(seconds: wait), () {
      if (!_manualClose && !_disposed) connect();
    });
  }

  Future<void> disconnect({bool reconnect = true}) async {
    if (!reconnect) _manualClose = true;
    _pingTimer?.cancel();
    _pingTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    if (_status != RealtimeStatus.disconnected) {
      _status = RealtimeStatus.disconnected;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    disconnect(reconnect: false);
    super.dispose();
  }
}
