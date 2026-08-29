import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../core/constants/server_config.dart';
import '../../server/services/server_service.dart';
import '../models/speed_result.dart';
import '../models/speed_test_state.dart';
import 'download_service.dart';
import 'ping_service.dart';
import 'upload_service.dart';

/// Orchestrates one speed-test run.
///
/// A run owns a monotonically increasing id. Results/progress from an older
/// run are therefore never allowed to leak into a newer run. Connectivity is
/// also monitored only while a run is active; a path change aborts the run so
/// we never publish a mixed-network result.
class SpeedTestService {
  final PingService _pingService;
  final DownloadService _downloadService;
  final UploadService _uploadService;
  final ServerService _serverService;
  final Connectivity _connectivity;
  final Future<List<ConnectivityResult>> Function()? _connectivityCheck;
  final Stream<List<ConnectivityResult>> Function()? _connectivityChanges;

  int _runId = 0;
  bool _active = false;
  final Map<int, SpeedTestException> _cancelReasons = <int, SpeedTestException>{};
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  String? _networkFingerprint;
  int? _connectivityRunId;

  SpeedTestLifecycle lifecycle = SpeedTestLifecycle.idle;

  SpeedTestService({
    PingService? pingService,
    DownloadService? downloadService,
    UploadService? uploadService,
    ServerService? serverService,
    Connectivity? connectivity,
    Future<List<ConnectivityResult>> Function()? connectivityCheck,
    Stream<List<ConnectivityResult>> Function()? connectivityChanges,
  })  : _pingService = pingService ?? PingService(),
        _downloadService = downloadService ?? DownloadService(),
        _uploadService = uploadService ?? UploadService(),
        _serverService = serverService ?? ServerService.instance,
        _connectivity = connectivity ?? Connectivity(),
        _connectivityCheck = connectivityCheck,
        _connectivityChanges = connectivityChanges;

  Future<void> warmUp() => _uploadService.warmUp();

  bool get isRunning => _active;

  void cancel({SpeedTestException? reason}) {
    if (!_active) return;
    final cancelledRunId = _runId;
    _cancelReasons[cancelledRunId] = reason ?? const SpeedTestCancelledException();
    _runId++;
    _active = false;
    lifecycle = SpeedTestLifecycle.stopping;
    _cancelChildren();
    unawaited(_stopConnectivityMonitor(runId: cancelledRunId));
  }

  void _cancelChildren() {
    _pingService.cancel();
    _downloadService.cancel();
    _uploadService.cancel();
  }

  Future<void> _startConnectivityMonitor(int runId) async {
    try {
      final initial = await (_connectivityCheck?.call() ?? _connectivity.checkConnectivity());
      if (!_isCurrent(runId)) return;
      _networkFingerprint = _fingerprint(initial);
      await _connectivitySub?.cancel();
      if (!_isCurrent(runId)) return;
      _connectivityRunId = runId;
      final changes = _connectivityChanges?.call() ?? _connectivity.onConnectivityChanged;
      _connectivitySub = changes.listen((list) {
        final next = _fingerprint(list);
        final previous = _networkFingerprint;
        _networkFingerprint = next;
        if (previous != null && previous != next && _isCurrent(runId)) {
          _cancelReasons[runId] = const SpeedTestNetworkChangedException();
          _runId++;
          _active = false;
          lifecycle = SpeedTestLifecycle.stopping;
          _cancelChildren();
          unawaited(_stopConnectivityMonitor(runId: runId));
        }
      });
    } catch (_) {
      // Connectivity monitoring is defensive. The actual HTTP test remains
      // authoritative if the plugin is unavailable.
    }
  }

  Future<void> _stopConnectivityMonitor({int? runId}) async {
    if (runId != null && _connectivityRunId != runId) return;
    await _connectivitySub?.cancel();
    // A newer run may have installed a different subscription while the old
    // cancellation was awaiting. Never clear the newer run's state.
    if (runId != null && _connectivityRunId != runId) return;
    _connectivitySub = null;
    _connectivityRunId = null;
    _networkFingerprint = null;
  }

  String _fingerprint(List<ConnectivityResult> list) {
    if (list.isEmpty) return 'none';
    final names = list.map((e) => e.name).toList()..sort();
    return names.join(',');
  }

  bool _isCurrent(int runId) => _active && runId == _runId;

  void _ensureCurrent(int runId) {
    final reason = _cancelReasons.remove(runId);
    if (reason != null) throw reason;
    if (!_isCurrent(runId)) {
      throw const SpeedTestCancelledException();
    }
  }

  Future<SpeedResult> start({
    void Function(SpeedTestPhase phase, double value)? onProgress,
    bool multiConnection = true,
  }) async {
    if (_active) {
      throw const SpeedTestException(
        SpeedTestErrorKind.unexpected,
        'A speed test is already running',
      );
    }

    final runId = ++_runId;
    _active = true;
    lifecycle = SpeedTestLifecycle.preparing;
    await _startConnectivityMonitor(runId);
    if (_networkFingerprint == 'none') {
      _active = false;
      lifecycle = SpeedTestLifecycle.failed;
      await _stopConnectivityMonitor(runId: runId);
      throw const SpeedTestNoInternetException();
    }

    final downloadThreads = multiConnection ? ServerConfig.downloadThreads : 1;
    final uploadThreads = multiConnection ? ServerConfig.uploadThreads : 1;
    final triedServers = <String>{};

    try {
      lifecycle = SpeedTestLifecycle.testing;

      // Up to two server attempts. A server failure can be retried on a
      // different server; cancellation/network-change is never retried.
      for (var attempt = 0; attempt < 2; attempt++) {
        _ensureCurrent(runId);
        final selectedId = _serverService.selected.id;
        triedServers.add(selectedId);

        try {
          onProgress?.call(SpeedTestPhase.ping, 0);
          final pingResult = await _pingService.test();
          _ensureCurrent(runId);
          onProgress?.call(SpeedTestPhase.ping, pingResult.ping);

          onProgress?.call(SpeedTestPhase.download, 0);
          final downloadResult = await _downloadService.test(
            threads: downloadThreads,
            onProgress: (speed) {
              if (_isCurrent(runId)) onProgress?.call(SpeedTestPhase.download, speed);
            },
          );
          _ensureCurrent(runId);
          if (downloadResult.bytes <= 0) {
            throw const SpeedTestServerException('Download server returned no data');
          }

          onProgress?.call(SpeedTestPhase.upload, 0);
          final uploadResult = await _uploadService.test(
            threads: uploadThreads,
            onProgress: (speed) {
              if (_isCurrent(runId)) onProgress?.call(SpeedTestPhase.upload, speed);
            },
          );
          _ensureCurrent(runId);
          if (uploadResult.bytes <= 0) {
            throw const SpeedTestServerException('Upload server returned no data');
          }

          final result = SpeedResult(
            ping: pingResult.ping,
            jitter: pingResult.jitter,
            avgPing: pingResult.avgPing,
            maxPing: pingResult.maxPing,
            packetLossPercent: pingResult.packetLossPercent,
            download: downloadResult.mbps,
            upload: uploadResult.mbps,
            server: ServerConfig.serverName,
            timestamp: DateTime.now(),
          );

          _ensureCurrent(runId);
          lifecycle = SpeedTestLifecycle.completed;
          onProgress?.call(SpeedTestPhase.completed, 100);
          return result;
        } on SpeedTestCancelledException {
          final reason = _cancelReasons.remove(runId);
          if (reason != null) throw reason;
          rethrow;
        } on SpeedTestNetworkChangedException {
          rethrow;
        } on SpeedTestServerException {
          if (attempt == 1 || !_switchToFallback(runId, triedServers)) rethrow;
        } on SpeedTestTimeoutException {
          if (attempt == 1 || !_switchToFallback(runId, triedServers)) rethrow;
        } on TimeoutException catch (e) {
          if (attempt == 1 || !_switchToFallback(runId, triedServers)) {
            throw SpeedTestTimeoutException('Speed test timed out: $e');
          }
        } on SocketException catch (e) {
          if (attempt == 1 || !_switchToFallback(runId, triedServers)) {
            throw SpeedTestTlsHttpException('Network/TLS error: ${e.message}', cause: e);
          }
        } on HttpException catch (e) {
          if (attempt == 1 || !_switchToFallback(runId, triedServers)) {
            throw SpeedTestTlsHttpException('HTTP error: ${e.message}', cause: e);
          }
        }
      }

      throw const SpeedTestServerException('No working speed-test server found');
    } finally {
      _cancelReasons.remove(runId);
      if (runId == _runId) {
        _uploadService.releaseCache();
        _active = false;
        if (lifecycle != SpeedTestLifecycle.completed) lifecycle = SpeedTestLifecycle.failed;
      }
      await _stopConnectivityMonitor(runId: runId);
    }
  }

  bool _switchToFallback(int runId, Set<String> tried) {
    if (!_isCurrent(runId)) return false;
    for (final server in _serverService.servers) {
      if (tried.contains(server.id)) continue;
      tried.add(server.id);
      _serverService.selectForTest(server);
      return true;
    }
    return false;
  }
}
