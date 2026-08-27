import 'dart:io';
import 'dart:math' as math;

import '../../../core/constants/server_config.dart';

/// Network latency metrics from HTTP RTT samples.
class PingResult {
  /// Best (lowest) latency in ms — primary displayed ping.
  final double ping;

  /// Mean absolute successive difference of stable samples (ms).
  final double jitter;

  /// Average latency of measured samples (ms), after light outlier trim.
  final double avgPing;

  /// Highest latency among measured samples (ms).
  final double maxPing;

  /// Failed samples / total attempted (0–100).
  final double packetLossPercent;

  /// Number of successful latency samples used.
  final int sampleCount;

  const PingResult({
    required this.ping,
    required this.jitter,
    required this.avgPing,
    required this.maxPing,
    required this.packetLossPercent,
    required this.sampleCount,
  });
}

class PingService {
  bool _cancelled = false;

  void cancel() => _cancelled = true;

  /// Lightweight HTTP latency probe:
  /// - keep-alive, HEAD first then GET range
  /// - many samples; primary ping = minimum (best latency)
  /// - also reports avg, max, jitter, and loss rate
  Future<PingResult> test({
    int samples = ServerConfig.pingSamples,
  }) async {
    _cancelled = false;
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 3);
    client.idleTimeout = const Duration(seconds: 15);
    client.userAgent = 'MPorT-TesSpeed/1.0';
    client.autoUncompress = false;

    final samplesMs = <double>[];
    var attempts = 0;
    var failures = 0;

    try {
      final total = samples + ServerConfig.pingWarmup;

      for (var i = 0; i < total; i++) {
        if (_cancelled) {
          throw const PingCancelledException();
        }
        final baseUri = Uri.parse(ServerConfig.pingUrl);
        final uri = baseUri.replace(
          queryParameters: {
            ...baseUri.queryParameters,
            'n': '${DateTime.now().microsecondsSinceEpoch}',
          },
        );

        final ms = await _onePing(client, uri);
        if (_cancelled) {
          throw const PingCancelledException();
        }
        // Count only post-warmup attempts toward loss stats
        if (i >= ServerConfig.pingWarmup) {
          attempts++;
          if (ms != null && ms > 0) {
            samplesMs.add(ms);
          } else {
            failures++;
          }
        }

        if (i < total - 1) {
          await Future<void>.delayed(
            const Duration(milliseconds: ServerConfig.pingIntervalMs),
          );
        }
      }
    } finally {
      client.close(force: true);
    }

    if (samplesMs.isEmpty) {
      throw Exception('Ping failed — server did not respond');
    }

    final sorted = List<double>.from(samplesMs)..sort();

    // Trim only the highest few values for the displayed average.
    var working = sorted;
    const trim = ServerConfig.pingTrimCount;
    if (working.length > trim + 2) {
      working = working.sublist(0, working.length - trim);
    }

    // Report measured RTT directly. Do not apply an arbitrary correction
    // factor: doing so makes the displayed latency systematically too low.
    final ping = math.max(0.1, sorted.first);
    final maxPing = math.max(0.1, sorted.last);
    final avgRaw = working.reduce((a, b) => a + b) / working.length;
    final avgPing = math.max(0.1, avgRaw);

    // Jitter must use chronological samples, not sorted samples.
    // Exclude the slowest 20% only as outliers.
    final p80Idx = (sorted.length * 0.80).ceil().clamp(1, sorted.length) - 1;
    final threshold = sorted[p80Idx];
    final stable = samplesMs.where((v) => v <= threshold).toList();
    final diffs = <double>[];
    for (var i = 1; i < stable.length; i++) {
      diffs.add((stable[i] - stable[i - 1]).abs());
    }
    final jitter = diffs.isEmpty
        ? 0.0
        : diffs.reduce((a, b) => a + b) / diffs.length;

    final loss = attempts > 0 ? (failures / attempts) * 100.0 : 0.0;

    return PingResult(
      ping: ping,
      jitter: jitter,
      avgPing: avgPing,
      maxPing: maxPing,
      packetLossPercent: loss,
      sampleCount: samplesMs.length,
    );
  }

  Future<double?> _onePing(HttpClient client, Uri uri) async {
    if (_cancelled) return null;
    try {
      final sw = Stopwatch()..start();
      final req = await client.openUrl('HEAD', uri);
      req.followRedirects = false;
      req.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      req.headers.set(HttpHeaders.acceptHeader, '*/*');
      req.headers.set(HttpHeaders.connectionHeader, 'keep-alive');

      final res = await req.close().timeout(const Duration(seconds: 2));
      await res.drain<void>();
      sw.stop();

      if (res.statusCode >= 200 && res.statusCode < 400) {
        return sw.elapsedMicroseconds / 1000.0;
      }
    } catch (_) {}

    try {
      final sw = Stopwatch()..start();
      final req = await client.getUrl(uri);
      req.followRedirects = false;
      req.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
      req.headers.set(HttpHeaders.connectionHeader, 'keep-alive');

      final res = await req.close().timeout(const Duration(seconds: 2));
      await res.drain<void>();
      sw.stop();

      if (res.statusCode >= 200 && res.statusCode < 400) {
        return sw.elapsedMicroseconds / 1000.0;
      }
    } catch (_) {}

    return null;
  }
}


class PingCancelledException implements Exception {
  const PingCancelledException();

  @override
  String toString() => 'Ping test cancelled';
}
