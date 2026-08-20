import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/constants/server_config.dart';

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
  final Random _random = Random();
  Uint8List? _cachedPayload;

  Uint8List _payload(int megabytes) {
    final size = megabytes * 1024 * 1024;
    if (_cachedPayload != null && _cachedPayload!.length == size) {
      return _cachedPayload!;
    }
    // Pattern filled payload (faster than per-byte random, still non-compressible enough)
    final data = Uint8List(size);
    for (var i = 0; i < size; i++) {
      data[i] = (i + _random.nextInt(3)) & 0xFF;
    }
    _cachedPayload = data;
    return data;
  }

  Future<UploadResult> test({
    Duration duration = const Duration(
      seconds: ServerConfig.uploadDurationSeconds,
    ),
    int threads = ServerConfig.uploadThreads,
    int payloadMegabytes = ServerConfig.uploadPayloadMegabytes,
    void Function(double mbps)? onProgress,
  }) async {
    final payload = _payload(payloadMegabytes);
    final stopwatch = Stopwatch()..start();
    final grace = const Duration(seconds: ServerConfig.gracePeriodSeconds);

    var totalBytes = 0;
    var graceBytes = 0;
    var running = true;
    var graceEnded = false;
    var lastProgressMs = 0;

    void endGraceIfNeeded() {
      if (!graceEnded && stopwatch.elapsed >= grace) {
        graceEnded = true;
        graceBytes = totalBytes;
      }
    }

    Future<void> worker() async {
      while (running) {
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

          final response = await request.send().timeout(
                const Duration(seconds: ServerConfig.receiveTimeoutSeconds),
              );

          await response.stream.drain<void>().timeout(
                const Duration(seconds: ServerConfig.receiveTimeoutSeconds),
              );

          if (response.statusCode < 200 || response.statusCode >= 300) {
            continue;
          }

          totalBytes += payload.length;
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
        throw Exception('Upload gagal');
      }
      final mbps =
          totalBytes * 8 / sec / 1e6 * ServerConfig.overheadAdjustment;
      return UploadResult(
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

    return UploadResult(
      mbps: mbps,
      bytes: measureBytes,
      duration: graceEnded ? stopwatch.elapsed - grace : stopwatch.elapsed,
    );
  }
}
