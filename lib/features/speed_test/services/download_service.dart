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

class DownloadService {
  bool _cancelled = false;

  /// Abort an in-flight test as soon as possible.
  void cancel() {
    _cancelled = true;
  }

  Future<DownloadResult> test({
    Duration duration = const Duration(
      seconds: ServerConfig.downloadDurationSeconds,
    ),
    int threads = ServerConfig.downloadThreads,
    void Function(double mbps)? onProgress,
  }) async {
    _cancelled = false;
    var totalBytes = 0;
    var graceBytes = 0;
    var running = true;
    var graceEnded = false;

    final stopwatch = Stopwatch()..start();
    const grace = Duration(seconds: ServerConfig.gracePeriodSeconds);
    var lastProgressMs = 0;

    void endGraceIfNeeded() {
      if (!graceEnded && stopwatch.elapsed >= grace) {
        graceEnded = true;
        graceBytes = totalBytes;
      }
    }

    Future<void> worker() async {
      while (running && !_cancelled) {
        try {
          final request = http.Request(
            'GET',
            Uri.parse(ServerConfig.downloadUrlBusted()),
          );
          request.headers.addAll(ServerConfig.defaultHeaders);

          final response = await request.send().timeout(
                const Duration(seconds: ServerConfig.connectTimeoutSeconds),
              );

          if (response.statusCode != 200) continue;

          await for (final chunk in response.stream) {
            if (_cancelled || !running || stopwatch.elapsed >= duration) {
              running = false;
              break;
            }

            totalBytes += chunk.length;
            endGraceIfNeeded();

            final measureBytes =
                graceEnded ? (totalBytes - graceBytes) : totalBytes;
            final measureSeconds = graceEnded
                ? (stopwatch.elapsed - grace).inMicroseconds / 1e6
                : stopwatch.elapsedMicroseconds / 1e6;

            if (measureSeconds > 0.3) {
              final mbps = measureBytes *
                  8 /
                  measureSeconds /
                  1e6 *
                  ServerConfig.overheadAdjustment;

              final now = stopwatch.elapsedMilliseconds;
              if (now - lastProgressMs >= ServerConfig.progressThrottleMs) {
                lastProgressMs = now;
                onProgress?.call(mbps);
              }
            }
          }
        } catch (_) {
          if (!running || _cancelled) break;
        }
      }
    }

    final workers = List.generate(threads, (_) => worker());

    // Wait for workers or overall timeout; cancel() sets _cancelled so workers exit.
    await Future.any([
      Future.wait(workers),
      Future<void>.delayed(duration + const Duration(seconds: 1)),
    ]);

    running = false;
    stopwatch.stop();
    endGraceIfNeeded();

    if (_cancelled) {
      final measureBytes =
          graceEnded ? (totalBytes - graceBytes) : totalBytes;
      final measureSeconds = graceEnded
          ? (stopwatch.elapsed - grace).inMicroseconds / 1e6
          : stopwatch.elapsedMicroseconds / 1e6;
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

    final measureBytes =
        graceEnded ? (totalBytes - graceBytes) : totalBytes;
    final measureSeconds = graceEnded
        ? (stopwatch.elapsed - grace).inMicroseconds / 1e6
        : stopwatch.elapsedMicroseconds / 1e6;

    if (totalBytes == 0 || stopwatch.elapsedMicroseconds == 0) {
      throw Exception('Download failed — no data received');
    }

    final sec = measureSeconds > 0.1
        ? measureSeconds
        : stopwatch.elapsedMicroseconds / 1e6;
    final mbps = measureBytes * 8 / sec / 1e6 * ServerConfig.overheadAdjustment;

    return DownloadResult(
      mbps: mbps,
      bytes: measureBytes,
      duration: stopwatch.elapsed,
    );
  }
}
