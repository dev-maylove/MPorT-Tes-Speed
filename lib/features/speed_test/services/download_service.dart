import 'dart:async';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../../../core/constants/server_config.dart';
import '../models/speed_test_state.dart';
import '../utils/throughput_math.dart';

class DownloadResult {
  final double mbps;
  final int bytes;
  final Duration duration;
  const DownloadResult({required this.mbps, required this.bytes, required this.duration});
}

class DownloadService {
  int _operationId = 0;
  final Set<http.Client> _activeClients = <http.Client>{};

  void cancel() {
    _operationId++;
    for (final client in List<http.Client>.from(_activeClients)) {
      try { client.close(); } catch (_) {}
    }
    _activeClients.clear();
  }

  Future<DownloadResult> test({
    Duration duration = const Duration(seconds: ServerConfig.downloadDurationSeconds),
    int threads = ServerConfig.downloadThreads,
    void Function(double mbps)? onProgress,
  }) async {
    final operationId = ++_operationId;
    final stopwatch = Stopwatch()..start();
    const grace = Duration(seconds: ServerConfig.gracePeriodSeconds);
    final threadCount = threads.clamp(1, 8).toInt();
    var totalBytes = 0;
    var graceBytes = 0;
    var running = true;
    var graceEnded = false;
    var activeMicros = 0;
    var lastTickMicros = grace.inMicroseconds;
    var lastTickBytes = 0;
    final intervalSamples = <double>[];
    var lastUiMs = 0;
    var httpFailures = 0;
    SpeedTestException? terminalError;

    bool current() => operationId == _operationId;

    void endGraceIfNeeded() {
      if (!graceEnded && stopwatch.elapsed >= grace) {
        graceEnded = true;
        graceBytes = totalBytes;
        lastTickBytes = totalBytes;
        lastTickMicros = stopwatch.elapsedMicroseconds;
      }
    }

    void sampleTick({bool force = false}) {
      if (!current()) return;
      endGraceIfNeeded();
      if (!graceEnded) return;
      final nowMicros = stopwatch.elapsedMicroseconds;
      final deltaMicros = nowMicros - lastTickMicros;
      final deltaBytes = totalBytes - lastTickBytes;
      if (deltaMicros > 0 && deltaBytes > 0) {
        activeMicros += deltaMicros;
        intervalSamples.add(measuredMbps(deltaBytes, deltaMicros / 1e6, overhead: ServerConfig.overheadAdjustment));
        if (intervalSamples.length > 12) intervalSamples.removeAt(0);
      }
      lastTickMicros = nowMicros;
      lastTickBytes = totalBytes;
      if (!force && nowMicros ~/ 1000 - lastUiMs < ServerConfig.progressThrottleMs) return;
      final live = robustLiveMbps(intervalSamples);
      if (live > 0) {
        lastUiMs = nowMicros ~/ 1000;
        onProgress?.call(live);
      }
    }

    final timer = Timer.periodic(const Duration(milliseconds: ServerConfig.sampleIntervalMs), (_) {
      if (running && current()) sampleTick();
    });

    Future<void> worker() async {
      final client = http.Client();
      _activeClients.add(client);
      try {
        while (running && current() && stopwatch.elapsed < duration) {
          try {
            final request = http.Request('GET', Uri.parse(ServerConfig.downloadUrlBusted()));
            request.headers.addAll(ServerConfig.defaultHeaders);
            final response = await client.send(request).timeout(
              const Duration(seconds: ServerConfig.connectTimeoutSeconds),
            );
            if (response.statusCode != 200) {
              httpFailures++;
              await response.stream.drain<void>().catchError((_) {});
              if (httpFailures >= 2) {
                terminalError = SpeedTestServerException('Download HTTP ${response.statusCode}');
                running = false;
                break;
              }
              continue;
            }
            httpFailures = 0;
            await for (final chunk in response.stream.timeout(
              const Duration(seconds: ServerConfig.receiveTimeoutSeconds),
            )) {
              if (!running || !current()) break;
              if (stopwatch.elapsed >= duration) {
                running = false;
                break;
              }
              totalBytes += chunk.length;
            }
          } on TimeoutException catch (e) {
            if (!running || !current()) break;
            terminalError = SpeedTestTimeoutException('Download timed out: $e');
            running = false;
            break;
          } on SocketException catch (e) {
            if (!running || !current()) break;
            httpFailures++;
            if (httpFailures >= 2) {
              terminalError = SpeedTestTlsHttpException('Network/TLS error: ${e.message}', cause: e);
              running = false;
              break;
            }
            await Future<void>.delayed(const Duration(milliseconds: 80));
          } on http.ClientException catch (e) {
            if (!running || !current()) break;
            httpFailures++;
            if (httpFailures >= 2) {
              terminalError = SpeedTestTlsHttpException('HTTP error: ${e.message}', cause: e);
              running = false;
              break;
            }
            await Future<void>.delayed(const Duration(milliseconds: 80));
          }
        }
      } finally {
        _activeClients.remove(client);
        try { client.close(); } catch (_) {}
      }
    }

    try {
      final workers = List.generate(threadCount, (_) => worker());
      await Future.any(<Future<void>>[
        Future.wait(workers),
        Future<void>.delayed(duration + const Duration(milliseconds: 700)),
      ]);
      running = false;
      for (final client in List<http.Client>.from(_activeClients)) {
        try { client.close(); } catch (_) {}
      }
      await Future.wait(workers);
    } finally {
      running = false;
      timer.cancel();
      for (final client in List<http.Client>.from(_activeClients)) {
        try { client.close(); } catch (_) {}
      }
      sampleTick(force: true);
      stopwatch.stop();
    }

    if (!current()) throw const SpeedTestCancelledException();
    if (terminalError != null) throw terminalError!;
    endGraceIfNeeded();
    final measuredBytes = math.max(0, totalBytes - graceBytes);
    final seconds = activeMicros / 1e6;
    if (measuredBytes <= 0 || seconds <= 0) {
      throw const SpeedTestTimeoutException('Download timed out or no data was received');
    }
    final mbps = measuredMbps(measuredBytes, seconds, overhead: ServerConfig.overheadAdjustment);
    if (mbps <= 0) throw const SpeedTestServerException('Download server returned no usable data');
    onProgress?.call(mbps);
    return DownloadResult(mbps: mbps, bytes: measuredBytes, duration: stopwatch.elapsed);
  }
}
