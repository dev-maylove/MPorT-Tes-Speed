import 'dart:async';

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

/// Multi-connection download test with Ookla-style top-10% sampling.
class DownloadService {
  bool _cancelled = false;
  http.Client? _client;

  void cancel() {
    _cancelled = true;
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

    // Instantaneous samples after grace (for final Ookla-style score)
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
        // Smooth for UI only
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
            if (_cancelled || !running) break;
            if (stopwatch.elapsed >= duration) {
              running = false;
              break;
            }
            totalBytes += chunk.length;
          }
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
      sampleTick(); // last sample
      stopwatch.stop();
      endGraceIfNeeded();
      try {
        client.close();
      } catch (_) {}
      if (identical(_client, client)) _client = null;
    }

    final measureBytes =
        graceEnded ? (totalBytes - graceBytes) : totalBytes;

    // Prefer Ookla-style top samples; fall back to total/time.
    var mbps = ooklaStyleMbps(samples);
    if (mbps <= 0 && measureBytes > 0) {
      final sec = graceEnded
          ? (stopwatch.elapsed - grace).inMicroseconds / 1e6
          : stopwatch.elapsedMicroseconds / 1e6;
      if (sec > 0.1) {
        mbps = measureBytes * 8 / sec / 1e6 * ServerConfig.overheadAdjustment;
      }
    }

    if (!_cancelled && totalBytes == 0) {
      throw Exception('Download failed — no data received');
    }

    if (mbps > 0) onProgress?.call(mbps);

    return DownloadResult(
      mbps: mbps,
      bytes: measureBytes,
      duration: stopwatch.elapsed,
    );
  }
}
