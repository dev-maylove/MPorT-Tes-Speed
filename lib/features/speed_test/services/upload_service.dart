import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/constants/server_config.dart';
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
  final Random _random = Random();
  Uint8List? _cachedPayload;
  bool _cancelled = false;
  http.Client? _client;

  void cancel() {
    _cancelled = true;
    try {
      _client?.close();
    } catch (_) {}
    _client = null;
  }

  Uint8List _payload(int megabytes) {
    final size = megabytes * 1024 * 1024;
    final cached = _cachedPayload;
    if (cached != null && cached.length == size) return cached;
    final data = Uint8List(size);
    final rnd = _random.nextInt(255);
    for (var i = 0; i < size; i += 256) {
      final end = (i + 256).clamp(0, size);
      for (var j = i; j < end; j++) {
        data[j] = (rnd + j) & 0xFF;
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
    _cancelled = false;
    final client = http.Client();
    _client = client;

    final payload = _payload(payloadMegabytes);
    final stopwatch = Stopwatch()..start();
    const grace = Duration(seconds: ServerConfig.gracePeriodSeconds);

    var totalBytes = 0;
    var graceBytes = 0;
    var running = true;
    var graceEnded = false;
    var successCount = 0;
    final threadCount = threads.clamp(1, 6);

    final samples = <double>[];
    var lastSampleBytes = 0;
    var lastSampleMs = 0;
    var smoothUi = 0.0;
    var lastUiMs = 0;

    void endGraceIfNeeded() {
      if (!graceEnded && stopwatch.elapsed >= grace) {
        graceEnded = true;
        graceBytes = totalBytes;
        lastSampleBytes = totalBytes;
        lastSampleMs = stopwatch.elapsedMilliseconds;
      }
    }

    void sampleTick() {
      endGraceIfNeeded();
      if (!graceEnded || _cancelled) return;
      final now = stopwatch.elapsedMilliseconds;
      final dt = (now - lastSampleMs) / 1000.0;
      if (dt < 0.08) return;
      final dBytes = totalBytes - lastSampleBytes;
      lastSampleBytes = totalBytes;
      lastSampleMs = now;
      if (dBytes <= 0) return;
      final inst = dBytes * 8 / dt / 1e6 * ServerConfig.overheadAdjustment;
      if (inst.isFinite && inst > 0) {
        samples.add(inst);
        smoothUi = ema(smoothUi, inst);
        if (onProgress != null &&
            now - lastUiMs >= ServerConfig.progressThrottleMs) {
          lastUiMs = now;
          onProgress(smoothUi);
        }
      }
    }

    final sampleTimer = Timer.periodic(
      Duration(milliseconds: ServerConfig.sampleIntervalMs),
      (_) {
        if (running && !_cancelled) sampleTick();
      },
    );

    Future<void> worker() async {
      while (running && !_cancelled) {
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

          if (response.statusCode >= 500) continue;

          totalBytes += payload.length;
          successCount++;
        } catch (_) {
          if (!running || _cancelled) break;
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

    final measureBytes =
        graceEnded ? (totalBytes - graceBytes) : totalBytes;

    var mbps = ooklaStyleMbps(samples);
    if (mbps <= 0 && measureBytes > 0) {
      final sec = graceEnded
          ? (stopwatch.elapsed - grace).inMicroseconds / 1e6
          : stopwatch.elapsedMicroseconds / 1e6;
      if (sec > 0.1) {
        mbps = measureBytes * 8 / sec / 1e6 * ServerConfig.overheadAdjustment;
      }
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
