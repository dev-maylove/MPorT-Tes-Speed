import 'dart:async';
import 'dart:io';
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
  http.Client? _client;

  void cancel() {
    _operationId++;
    try { _client?.close(); } catch (_) {}
    _client = null;
  }

  Future<DownloadResult> test({
    Duration duration = const Duration(seconds: ServerConfig.downloadDurationSeconds),
    int threads = ServerConfig.downloadThreads,
    void Function(double mbps)? onProgress,
  }) async {
    final operationId = ++_operationId;
    final client = http.Client();
    _client = client;
    final stopwatch = Stopwatch()..start();
    final deadline = duration;
    const grace = Duration(seconds: ServerConfig.gracePeriodSeconds);
    final threadCount = threads.clamp(1, 8);

    var totalBytes = 0;
    var graceBytes = 0;
    var running = true;
    var graceEnded = false;
    var activeMicros = 0;
    var lastTickMicros = grace.inMicroseconds;
    var lastTickBytes = 0;
    final intervalSamples = <double>[];
    var lastUiMs = 0;
    SpeedTestException? terminalError;

    bool current() => operationId == _operationId;
    bool cancelled() => !current();

    void endGraceIfNeeded() {
      if (!graceEnded && stopwatch.elapsed >= grace) {
        graceEnded = true;
        graceBytes = totalBytes;
        lastTickBytes = totalBytes;
        lastTickMicros = stopwatch.elapsedMicroseconds;
      }
    }

    void sampleTick({bool force = false}) {
      endGraceIfNeeded();
      if (!graceEnded || cancelled()) return;
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
      final activeSec = activeMicros / 1e6;
      final live = robustLiveMbps(intervalSamples);
      if (live > 0) {
        lastUiMs = nowMicros ~/ 1000;
        onProgress?.call(live);
      } else if (activeSec > 0) {
        final aggregate = measuredMbps(math.max(0, totalBytes - graceBytes), activeSec, overhead: ServerConfig.overheadAdjustment);
        if (aggregate > 0) onProgress?.call(aggregate);
      }
    }

    final timer = Timer.periodic(const Duration(milliseconds: ServerConfig.sampleIntervalMs), (_) {
      if (running && current()) sampleTick();
    });

    Future<void> worker() async {
      // Per-worker failure budget: one bad stream must not abort healthy parallel downloads.
      var workerFailures = 0;
      while (running && current()) {
        if (stopwatch.elapsed >= deadline) { running = false; break; }
        try {
          final request = http.Request('GET', Uri.parse(ServerConfig.downloadUrlBusted()));
          request.headers.addAll(ServerConfig.defaultHeaders);
          final response = await client.send(request).timeout(const Duration(seconds: ServerConfig.connectTimeoutSeconds));
          if (response.statusCode != 200) {
            workerFailures++;
            await response.stream.drain<void>().catchError((_) {});
            if (workerFailures >= 3) {
              terminalError ??= SpeedTestServerException('Download HTTP ${response.statusCode}');
              break;
            }
            continue;
          }
          workerFailures = 0;
          await for (final chunk in response.stream.timeout(const Duration(seconds: ServerConfig.receiveTimeoutSeconds))) {
            if (!running || cancelled()) break;
            if (stopwatch.elapsed >= deadline) { running = false; break; }
            totalBytes += chunk.length;
          }
        } on SpeedTestServerException catch (e) {
          terminalError ??= e;
          break;
        } on SocketException {
          if (!running || cancelled()) break;
          workerFailures++;
          if (workerFailures >= 4) break;
          if (current()) {
            await Future<void>.delayed(const Duration(milliseconds: 40));
          }
        } on TimeoutException {
          if (!running || cancelled()) break;
          workerFailures++;
          if (workerFailures >= 4) break;
          if (running && current()) await Future<void>.delayed(const Duration(milliseconds: 40));
        } catch (_) {
          if (!running || cancelled()) break;
          workerFailures++;
          if (workerFailures >= 4) break;
          await Future<void>.delayed(const Duration(milliseconds: 40));
        }
      }
    }

    try {
      final workers = List.generate(threadCount, (_) => worker());
      await Future.any([Future.wait(workers), Future<void>.delayed(deadline + const Duration(milliseconds: 600))]);
    } finally {
      running = false;
      timer.cancel();
      sampleTick(force: true);
      stopwatch.stop();
      try { client.close(); } catch (_) {}
      if (identical(_client, client)) _client = null;
    }

    if (cancelled()) throw const SpeedTestCancelledException();
    endGraceIfNeeded();
    final measuredBytes = math.max(0, totalBytes - graceBytes);
    final seconds = activeMicros / 1e6;
    if (measuredBytes <= 0 || seconds <= 0) {
      if (terminalError != null) throw terminalError!;
      throw const SpeedTestTimeoutException('Download timed out or no data was received');
    }
    final mbps = measuredMbps(measuredBytes, seconds, overhead: ServerConfig.overheadAdjustment);
    if (mbps <= 0) throw const SpeedTestServerException('Download server returned no usable data');
    onProgress?.call(mbps);
    return DownloadResult(mbps: mbps, bytes: measuredBytes, duration: stopwatch.elapsed);
  }
}
