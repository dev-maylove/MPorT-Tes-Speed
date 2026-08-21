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
    final cached = _cachedPayload;
    if (cached != null && cached.length == size) {
      return cached;
    }
    final data = Uint8List(size);
    for (var i = 0; i < size; i += 64) {
      final v = (i + _random.nextInt(7)) & 0xFF;
      final end = (i + 64).clamp(0, size);
      for (var j = i; j < end; j++) {
        data[j] = (v + j) & 0xFF;
      }
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
    const grace = Duration(seconds: ServerConfig.gracePeriodSeconds);

    var totalBytes = 0;
    var graceBytes = 0;
    var running = true;
    var graceEnded = false;
    var lastProgressMs = 0;
    var successCount = 0;

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
                const Duration(seconds: 12),
              );

          // Drain response (ignore body content)
          try {
            await response.stream.drain<void>().timeout(
                  const Duration(seconds: 8),
                );
          } catch (_) {}

          // Terima status 2xx/3xx/4xx (banyak server balas 200/204/405/413 tapi data terkirim)
          // Hanya skip 5xx berat
          if (response.statusCode >= 500) {
            continue;
          }

          totalBytes += payload.length;
          successCount++;
          endGraceIfNeeded();

          final measureBytes =
              graceEnded ? (totalBytes - graceBytes) : totalBytes;
          final measureSeconds = graceEnded
              ? (stopwatch.elapsed - grace).inMicroseconds / 1e6
              : stopwatch.elapsedMicroseconds / 1e6;

          if (measureSeconds > 0.25) {
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
          // Lanjut coba request berikutnya
        }
      }
    }

    final workers = List.generate(threads, (_) => worker());

    await Future.any([
      Future.wait(workers),
      Future.delayed(duration + const Duration(seconds: 1)),
    ]);

    running = false;
    stopwatch.stop();
    endGraceIfNeeded();

    final measureBytes =
        graceEnded ? (totalBytes - graceBytes) : totalBytes;
    final measureSeconds = graceEnded
        ? (stopwatch.elapsed - grace).inMicroseconds / 1e6
        : stopwatch.elapsedMicroseconds / 1e6;

    // Jika ada data terkirim, jangan throw — kembalikan hasil terbaik
    if (totalBytes > 0 && stopwatch.elapsedMicroseconds > 0) {
      final sec = measureSeconds > 0.1
          ? measureSeconds
          : stopwatch.elapsedMicroseconds / 1e6;
      final bytes = measureBytes > 0 ? measureBytes : totalBytes;
      final mbps =
          bytes * 8 / sec / 1e6 * ServerConfig.overheadAdjustment;
      return UploadResult(
        mbps: mbps,
        bytes: bytes,
        duration: stopwatch.elapsed,
      );
    }

    // Sama sekali gagal
    throw Exception('Upload gagal — server tidak menerima data ($successCount OK)');
  }
}
