import 'dart:async';

import 'package:http/http.dart' as http;

import '../../../core/constants/server_config.dart';

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

/// Multi-connection download throughput test (UI-friendly).
///
/// Optimizations vs naive loop:
/// - Shared [http.Client] (connection reuse / keep-alive)
/// - Byte counting only on the hot path; Mbps computed on a timer
/// - Progress callbacks throttled off the stream (no per-chunk UI math)
/// - Response streams closed promptly on cancel / timeout
class DownloadService {
  bool _cancelled = false;
  http.Client? _client;

  void cancel() {
    _cancelled = true;
    // Closing the client aborts in-flight requests quickly.
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
    final client = http.Client();
    _client = client;

    var totalBytes = 0;
    var graceBytes = 0;
    var running = true;
    var graceEnded = false;

    final stopwatch = Stopwatch()..start();
    const grace = Duration(seconds: ServerConfig.gracePeriodSeconds);
    final threadCount = threads.clamp(1, 8);

    void endGraceIfNeeded() {
      if (!graceEnded && stopwatch.elapsed >= grace) {
        graceEnded = true;
        graceBytes = totalBytes;
      }
    }

    double currentMbps() {
      endGraceIfNeeded();
      final measureBytes =
          graceEnded ? (totalBytes - graceBytes) : totalBytes;
      final measureSeconds = graceEnded
          ? (stopwatch.elapsed - grace).inMicroseconds / 1e6
          : stopwatch.elapsedMicroseconds / 1e6;
      if (measureSeconds < 0.2 || measureBytes <= 0) return 0;
      return measureBytes * 8 / measureSeconds / 1e6 * ServerConfig.overheadAdjustment;
    }

    // Progress on a fixed cadence — keeps UI smooth and off the byte path.
    Timer? progressTimer;
    if (onProgress != null) {
      progressTimer = Timer.periodic(
        Duration(milliseconds: ServerConfig.progressThrottleMs),
        (_) {
          if (!running || _cancelled) return;
          final mbps = currentMbps();
          if (mbps > 0) onProgress(mbps);
        },
      );
    }

    Future<void> worker() async {
      while (running && !_cancelled) {
        if (stopwatch.elapsed >= duration) {
          running = false;
          break;
        }
        http.StreamedResponse? response;
        try {
          final request = http.Request(
            'GET',
            Uri.parse(ServerConfig.downloadUrlBusted()),
          );
          request.headers.addAll(ServerConfig.defaultHeaders);

          response = await client.send(request).timeout(
                const Duration(seconds: ServerConfig.connectTimeoutSeconds),
              );

          if (response.statusCode != 200) {
            // Brief backoff on error to avoid tight fail loops
            await Future<void>.delayed(const Duration(milliseconds: 40));
            continue;
          }

          await for (final chunk in response.stream) {
            if (_cancelled || !running) break;
            if (stopwatch.elapsed >= duration) {
              running = false;
              break;
            }
            // Hot path: only count bytes (no floating math here)
            totalBytes += chunk.length;
          }
        } catch (_) {
          if (!running || _cancelled) break;
          await Future<void>.delayed(const Duration(milliseconds: 30));
        }
      }
    }

    try {
      final workers = List.generate(threadCount, (_) => worker());
      await Future.any([
        Future.wait(workers),
        Future<void>.delayed(duration + const Duration(milliseconds: 400)),
      ]);
    } finally {
      running = false;
      progressTimer?.cancel();
      stopwatch.stop();
      endGraceIfNeeded();
      try {
        client.close();
      } catch (_) {}
      if (identical(_client, client)) _client = null;
    }

    final measureBytes =
        graceEnded ? (totalBytes - graceBytes) : totalBytes;
    final measureSeconds = graceEnded
        ? (stopwatch.elapsed - grace).inMicroseconds / 1e6
        : stopwatch.elapsedMicroseconds / 1e6;

    if (_cancelled) {
      final sec = measureSeconds > 0.05
          ? measureSeconds
          : (stopwatch.elapsedMicroseconds / 1e6).clamp(0.05, 1e9);
      final mbps = totalBytes > 0
          ? measureBytes * 8 / sec / 1e6 * ServerConfig.overheadAdjustment
          : 0.0;
      return DownloadResult(
        mbps: mbps,
        bytes: measureBytes,
        duration: stopwatch.elapsed,
      );
    }

    if (totalBytes == 0 || stopwatch.elapsedMicroseconds == 0) {
      throw Exception('Download failed — no data received');
    }

    final sec = measureSeconds > 0.15
        ? measureSeconds
        : stopwatch.elapsedMicroseconds / 1e6;
    final mbps =
        measureBytes * 8 / sec / 1e6 * ServerConfig.overheadAdjustment;

    // Final progress tick
    onProgress?.call(mbps);

    return DownloadResult(
      mbps: mbps,
      bytes: measureBytes,
      duration: stopwatch.elapsed,
    );
  }
}
