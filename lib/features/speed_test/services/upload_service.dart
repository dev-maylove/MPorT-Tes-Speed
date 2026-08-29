import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/constants/server_config.dart';
import '../models/speed_test_state.dart';
import '../utils/isolate_workers.dart';
import '../utils/throughput_math.dart';

class UploadResult {
  final double mbps;
  final int bytes;
  final Duration duration;
  const UploadResult({required this.mbps, required this.bytes, required this.duration});
}

class UploadService {
  Uint8List? _cachedPayload;
  Future<Uint8List>? _warmInFlight;
  int _operationId = 0;
  int _payloadGeneration = 0;
  http.Client? _client;

  void cancel() {
    _operationId++;
    try { _client?.close(); } catch (_) {}
    _client = null;
  }

  void releaseCache() {
    _payloadGeneration++;
    _cachedPayload = null;
    _warmInFlight = null;
  }

  Future<void> warmUp({int megabytes = ServerConfig.uploadPayloadMegabytes}) async {
    try { await _payloadAsync(megabytes); } catch (_) {}
  }

  Future<Uint8List> _payloadAsync(int megabytes) async {
    final size = megabytes * 1024 * 1024;
    final cached = _cachedPayload;
    if (cached != null && cached.length == size) return cached;
    final inflight = _warmInFlight;
    if (inflight != null) return inflight;
    final generation = _payloadGeneration;
    final future = generateUploadPayload(megabytes).then((data) {
      if (generation == _payloadGeneration) _cachedPayload = data;
      return data;
    });
    _warmInFlight = future;
    try { return await future; }
    finally { if (identical(_warmInFlight, future)) _warmInFlight = null; }
  }

  Future<UploadResult> test({
    Duration duration = const Duration(seconds: ServerConfig.uploadDurationSeconds),
    int threads = ServerConfig.uploadThreads,
    int payloadMegabytes = ServerConfig.uploadPayloadMegabytes,
    void Function(double mbps)? onProgress,
  }) async {
    final operationId = ++_operationId;
    final client = http.Client();
    _client = client;
    final payload = await _payloadAsync(payloadMegabytes);
    if (operationId != _operationId) {
      client.close();
      if (identical(_client, client)) _client = null;
      throw const SpeedTestCancelledException();
    }

    final stopwatch = Stopwatch()..start();
    const grace = Duration(seconds: ServerConfig.gracePeriodSeconds);
    final threadCount = threads.clamp(1, 6);
    var totalBytes = 0;
    var graceBytes = 0;
    var running = true;
    var graceEnded = false;
    var activeMicros = 0;
    var lastTickMicros = grace.inMicroseconds;
    var lastTickBytes = 0;
    final intervals = <double>[];
    var lastUiMs = 0;
    var httpFailures = 0;

    bool current() => operationId == _operationId;
    void endGrace() {
      if (!graceEnded && stopwatch.elapsed >= grace) {
        graceEnded = true;
        graceBytes = totalBytes;
        lastTickBytes = totalBytes;
        lastTickMicros = stopwatch.elapsedMicroseconds;
      }
    }
    void sampleTick({bool force = false}) {
      endGrace();
      if (!graceEnded || !current()) return;
      final now = stopwatch.elapsedMicroseconds;
      final dt = now - lastTickMicros;
      final db = totalBytes - lastTickBytes;
      if (dt > 0 && db > 0) {
        activeMicros += dt;
        intervals.add(measuredMbps(db, dt / 1e6, overhead: ServerConfig.overheadAdjustment));
        if (intervals.length > 12) intervals.removeAt(0);
      }
      lastTickMicros = now;
      lastTickBytes = totalBytes;
      if (!force && now ~/ 1000 - lastUiMs < ServerConfig.progressThrottleMs) return;
      final live = robustLiveMbps(intervals);
      if (live > 0) { lastUiMs = now ~/ 1000; onProgress?.call(live); }
    }

    final timer = Timer.periodic(const Duration(milliseconds: ServerConfig.sampleIntervalMs), (_) {
      if (running && current()) sampleTick();
    });

    Future<void> worker() async {
      while (running && current()) {
        if (stopwatch.elapsed >= duration) { running = false; break; }
        try {
          final request = http.Request('POST', Uri.parse(ServerConfig.uploadUrlBusted()));
          request.headers.addAll(ServerConfig.uploadHeaders);
          request.bodyBytes = payload;
          final response = await client.send(request).timeout(const Duration(seconds: 12));
          try { await response.stream.drain<void>().timeout(const Duration(seconds: 8)); } catch (_) {}
          if (response.statusCode < 200 || response.statusCode >= 300) {
            httpFailures++;
            if (httpFailures >= 2) {
              throw SpeedTestServerException('Upload HTTP ${response.statusCode}');
            }
            continue;
          }
          httpFailures = 0;
          if (stopwatch.elapsed <= duration && current()) totalBytes += payload.length;
        } on SpeedTestServerException {
          if (current()) rethrow;
        } on TimeoutException {
          if (running && current()) await Future<void>.delayed(const Duration(milliseconds: 40));
        } catch (_) {
          if (!running || !current()) break;
          await Future<void>.delayed(const Duration(milliseconds: 40));
        }
      }
    }

    try {
      final workers = List.generate(threadCount, (_) => worker());
      await Future.any([Future.wait(workers), Future<void>.delayed(duration + const Duration(milliseconds: 700))]);
    } finally {
      running = false;
      timer.cancel();
      sampleTick(force: true);
      stopwatch.stop();
      try { client.close(); } catch (_) {}
      if (identical(_client, client)) _client = null;
    }

    if (!current()) throw const SpeedTestCancelledException();
    endGrace();
    final bytes = math.max(0, totalBytes - graceBytes);
    final seconds = activeMicros / 1e6;
    if (bytes <= 0 || seconds <= 0) throw const SpeedTestTimeoutException('Upload timed out or no data was accepted');
    final mbps = measuredMbps(bytes, seconds, overhead: ServerConfig.overheadAdjustment);
    if (mbps <= 0) throw const SpeedTestServerException('Upload server returned no usable data');
    onProgress?.call(mbps);
    return UploadResult(mbps: mbps, bytes: bytes, duration: stopwatch.elapsed);
  }
}
