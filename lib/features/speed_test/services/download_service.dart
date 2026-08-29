import 'dart:async';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../../../core/constants/server_config.dart';
import '../utils/throughput_math.dart';

class DownloadResult {
  final double mbps;
  final int bytes;
  final Duration duration;

  const DownloadResult({
    required this.mbps,
    required this.bytes,
    required this.duration,
  });
}

/// Multi-connection download test with a shared measured-window throughput score.
class DownloadService {
  bool _cancelled = false;
  http.Client? _client;
  int _operationId = 0;

  void cancel() {
    _cancelled = true;
    _operationId++;
    try {
      _client?.close();
    } catch (_) {}
    _client = null;
  }

  Future<DownloadResult> test({
    Duration duration = const Duration(
      seconds: ServerConfig.downloadDurationSeconds,
    ),
    int threads = ServerConfig.downloadThreads,
    void Function(double mbps)? onProgress,
  }) async {
    _cancelled = false;
    final operationId = ++_operationId;
    final client = http.Client();
    _client = client;

    var totalBytes = 0;
    var graceBytes = 0;
    var running = true;
    var graceEnded = false;

    final stopwatch = Stopwatch()..start();
    const grace = Duration(seconds: ServerConfig.gracePeriodSeconds);
    final threadCount = threads.clamp(1, 8);

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
      final elapsedSec = graceEnded
          ? (stopwatch.elapsed - grace).inMicroseconds / 1e6
          : stopwatch.elapsedMicroseconds / 1e6;
      final measuredBytes = graceEnded ? totalBytes - graceBytes : totalBytes;
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
            'GET',
            Uri.parse(ServerConfig.downloadUrlBusted()),
          );
          request.headers.addAll(ServerConfig.defaultHeaders);

          final response = await client.send(request).timeout(
                const Duration(seconds: ServerConfig.connectTimeoutSeconds),
              );

          if (response.statusCode != 200) {
            await Future<void>.delayed(const Duration(milliseconds: 50));
            continue;
          }

          await for (final chunk in response.stream) {
            if (_cancelled || !running || operationId != _operationId) break;
            if (stopwatch.elapsed >= duration) {
              running = false;
              break;
            }
            totalBytes += chunk.length;
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
      sampleTick(); // last sample
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

    if (!_cancelled && operationId == _operationId && totalBytes == 0) {
      throw Exception('Download failed — no data received');
    }

    if (!_cancelled && operationId == _operationId && mbps > 0) {
      onProgress?.call(mbps);
    }

    return DownloadResult(
      mbps: mbps,
      bytes: measureBytes,
      duration: stopwatch.elapsed,
    );
  }
}
