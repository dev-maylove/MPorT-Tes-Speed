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
  Future<DownloadResult> test({
    Duration duration = const Duration(
      seconds: ServerConfig.downloadDurationSeconds,
    ),
    int threads = ServerConfig.downloadThreads,
    void Function(double mbps)? onProgress,
  }) async {
    var totalBytes = 0;
    var graceBytes = 0;
    var running = true;
    var graceEnded = false;

    final stopwatch = Stopwatch()..start();
    final grace = const Duration(seconds: ServerConfig.gracePeriodSeconds);
    var lastProgressMs = 0;

    void endGraceIfNeeded() {
      if (!graceEnded && stopwatch.elapsed >= grace) {
        graceEnded = true;
        graceBytes = totalBytes;
      }
    }

    Future<void> worker() async {
      while (running) {
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
            if (!running || stopwatch.elapsed >= duration) {
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
          if (!running) break;
        }
      }
    }

    final workers = List.generate(threads, (_) => worker());

    await Future.any([
      Future.wait(workers),
      Future.delayed(duration),
    ]);

    running = false;
    stopwatch.stop();
    endGraceIfNeeded();

    final measureBytes =
        graceEnded ? (totalBytes - graceBytes) : totalBytes;
    final measureSeconds = graceEnded
        ? (stopwatch.elapsed - grace).inMicroseconds / 1e6
        : stopwatch.elapsedMicroseconds / 1e6;

    if (measureSeconds <= 0 || measureBytes <= 0) {
      final sec = stopwatch.elapsedMicroseconds / 1e6;
      if (sec <= 0 || totalBytes <= 0) {
        throw Exception('Download gagal');
      }
      final mbps =
          totalBytes * 8 / sec / 1e6 * ServerConfig.overheadAdjustment;
      return DownloadResult(
        mbps: mbps,
        bytes: totalBytes,
        duration: stopwatch.elapsed,
      );
    }

    final mbps = measureBytes *
        8 /
        measureSeconds /
        1e6 *
        ServerConfig.overheadAdjustment;

    return DownloadResult(
      mbps: mbps,
      bytes: measureBytes,
      duration: graceEnded ? stopwatch.elapsed - grace : stopwatch.elapsed,
    );
  }
}
