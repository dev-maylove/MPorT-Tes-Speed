import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../../../core/constants/server_config.dart';
import '../utils/isolate_workers.dart';
import '../utils/throughput_math.dart';

class UploadResult {
  final double mbps;
  final int bytes;
  final Duration duration;

  const UploadResult({
    required this.mbps,
    required this.bytes,
    required this.duration,
  });
}

class UploadService {
  Uint8List? _cachedPayload;
  Future<Uint8List>? _warmInFlight;
  bool _cancelled = false;
  int _operationId = 0;
  int _payloadGeneration = 0;
  http.Client? _client;

  void cancel() {
    _cancelled = true;
    _operationId++;
    try {
      _client?.close();
    } catch (_) {}
    _client = null;
  }

  /// Drop cached upload body to free Dart heap (~2 MiB).
  void releaseCache() {
    // Invalidate an in-flight payload generation. The future may still finish,
    // but its completion handler must not repopulate the cache after release.
    _payloadGeneration++;
    _cachedPayload = null;
    _warmInFlight = null;
  }

  /// Pre-warm payload on a background isolate (non-blocking for UI).
  Future<void> warmUp({
    int megabytes = ServerConfig.uploadPayloadMegabytes,
  }) async {
    try {
      await _payloadAsync(megabytes);
    } catch (_) {}
  }

  Future<Uint8List> _payloadAsync(int megabytes) async {
    final size = megabytes * 1024 * 1024;
    final cached = _cachedPayload;
    if (cached != null && cached.length == size) return cached;

    // Coalesce concurrent warmUp + test calls.
    final inflight = _warmInFlight;
    if (inflight != null) return inflight;

    final generation = _payloadGeneration;
    final future = generateUploadPayload(megabytes).then((data) {
      if (generation == _payloadGeneration) {
        _cachedPayload = data;
      }
      return data;
    });
    _warmInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_warmInFlight, future)) {
        _warmInFlight = null;
      }
    }
  }

  Future<UploadResult> test({
    Duration duration = const Duration(
      seconds: ServerConfig.uploadDurationSeconds,
    ),
    int threads = ServerConfig.uploadThreads,
    int payloadMegabytes = ServerConfig.uploadPayloadMegabytes,
    void Function(double mbps)? onProgress,
  }) async {
    _cancelled = false;
    final operationId = ++_operationId;
    final client = http.Client();
    _client = client;

    // Build / reuse payload off the UI isolate.
    final payload = await _payloadAsync(payloadMegabytes);
    if (_cancelled || operationId != _operationId) {
      try {
        client.close();
      } catch (_) {}
      if (identical(_client, client)) _client = null;
      return const UploadResult(mbps: 0, bytes: 0, duration: Duration.zero);
    }

    final stopwatch = Stopwatch()..start();
    const grace = Duration(seconds: ServerConfig.gracePeriodSeconds);

    var totalBytes = 0;
    var graceBytes = 0;
    var running = true;
    var graceEnded = false;
    var successCount = 0;
    final threadCount = threads.clamp(1, 6);

    var lastUiMs = 0;

    void endGraceIfNeeded() {
      if (!graceEnded && stopwatch.elapsed >= grace) {
        graceEnded = true;
        graceBytes = totalBytes;
      }
    }

    void sampleTick() {
      endGraceIfNeeded();
      if (!graceEnded || _cancelled) return;
      final now = stopwatch.elapsedMilliseconds;
      if (now - lastUiMs < ServerConfig.progressThrottleMs) return;
      final elapsedSec = (stopwatch.elapsed - grace).inMicroseconds / 1e6;
      final measuredBytes = totalBytes - graceBytes;
      final liveMbps = measuredMbps(
        measuredBytes,
        elapsedSec,
        overhead: ServerConfig.overheadAdjustment,
      );
      if (liveMbps <= 0) return;
      lastUiMs = now;
      onProgress?.call(liveMbps);
    }

    final sampleTimer = Timer.periodic(
      const Duration(milliseconds: ServerConfig.sampleIntervalMs),
      (_) {
        if (running && !_cancelled) sampleTick();
      },
    );

    Future<void> worker() async {
      while (running && !_cancelled && operationId == _operationId) {
        if (stopwatch.elapsed >= duration) {
          running = false;
          break;
        }
        try {
          final request = http.Request(
            'POST',
            Uri.parse(ServerConfig.uploadUrlBusted()),
          );
          request.headers.addAll(ServerConfig.uploadHeaders);
          request.bodyBytes = payload;

          final response = await client.send(request).timeout(
                const Duration(seconds: 12),
              );

          try {
            await response.stream.drain<void>().timeout(
                  const Duration(seconds: 8),
                );
          } catch (_) {}

          if (response.statusCode < 200 || response.statusCode >= 300) continue;

          if (stopwatch.elapsed <= duration) {
            totalBytes += payload.length;
            successCount++;
          }
        } catch (_) {
          if (!running || _cancelled || operationId != _operationId) break;
          await Future<void>.delayed(const Duration(milliseconds: 40));
        }
      }
    }

    try {
      final workers = List.generate(threadCount, (_) => worker());
      await Future.any([
        Future.wait(workers),
        Future<void>.delayed(duration + const Duration(milliseconds: 500)),
      ]);
    } finally {
      running = false;
      sampleTimer.cancel();
      sampleTick();
      stopwatch.stop();
      endGraceIfNeeded();
      try {
        client.close();
      } catch (_) {}
      if (identical(_client, client)) _client = null;
    }

    final measureBytes = graceEnded
        ? math.max(0, totalBytes - graceBytes)
        : totalBytes;
    // The measurement window ends at the configured deadline, not when a
    // late HTTP worker happens to finish. This keeps the denominator stable.
    final elapsedForScore = stopwatch.elapsed < duration ? stopwatch.elapsed : duration;
    final measuredDuration = graceEnded
        ? elapsedForScore - grace
        : elapsedForScore;
    final measureSec = math.max(0.0, measuredDuration.inMicroseconds / 1e6);

    // Final score uses the exact same byte/time formula as the live gauge.
    final mbps = measuredMbps(
      measureBytes,
      measureSec,
      overhead: ServerConfig.overheadAdjustment,
    );

    if (_cancelled || operationId != _operationId) {
      return const UploadResult(mbps: 0, bytes: 0, duration: Duration.zero);
    }

    if (totalBytes == 0) {
      throw Exception(
        'Upload failed — server did not accept data ($successCount OK)',
      );
    }

    if (mbps > 0) onProgress?.call(mbps);

    return UploadResult(
      mbps: mbps,
      bytes: measureBytes,
      duration: stopwatch.elapsed,
    );
  }
}
