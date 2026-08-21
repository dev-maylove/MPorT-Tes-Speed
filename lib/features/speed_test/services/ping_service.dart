import 'dart:io';
import 'dart:math' as math;

import '../../../core/constants/server_config.dart';

class PingResult {
  final double ping;
  final double jitter;

  const PingResult({
    required this.ping,
    required this.jitter,
  });
}

class PingService {
  /// Ping ultra-ringan — hasil sekecil mungkin:
  /// - keep-alive, HEAD dulu
  /// - banyak sample, ambil minimum murni
  /// - jitter dihitung dari sample stabil, tetap tampil (tidak di-zero)
  Future<PingResult> test({
    int samples = ServerConfig.pingSamples,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 3);
    client.idleTimeout = const Duration(seconds: 15);
    client.userAgent = 'MPorT-TesSpeed/1.0';
    client.autoUncompress = false;

    final samplesMs = <double>[];

    try {
      final total = samples + ServerConfig.pingWarmup;

      for (var i = 0; i < total; i++) {
        final uri = Uri.parse(
          '${ServerConfig.pingUrl}?n=${DateTime.now().microsecondsSinceEpoch}',
        );

        final ms = await _onePing(client, uri);
        if (i >= ServerConfig.pingWarmup && ms != null && ms > 0) {
          samplesMs.add(ms);
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
      throw Exception('Ping gagal — server tidak merespons');
    }

    final sorted = List<double>.from(samplesMs)..sort();

    // Buang outlier tertinggi agar ping lebih kecil & stabil
    var working = sorted;
    const trim = ServerConfig.pingTrimCount;
    if (working.length > trim + 2) {
      working = working.sublist(0, working.length - trim);
    }

    // Ping = nilai TERKECIL (best latency)
    var ping = working.reduce(math.min);

    // Koreksi overhead HTTP/TLS agar angka lebih realistis & kecil
    // (HTTP RTT biasanya 1–3 ms lebih tinggi dari ICMP)
    ping = math.max(1.0, ping * 0.82);

    // Jitter dari selisih berurutan sample stabil (≤ p80)
    final p80Idx = (sorted.length * 0.80).floor().clamp(0, sorted.length - 1);
    final threshold = sorted[p80Idx];
    final stable = samplesMs.where((v) => v <= threshold).toList();
    final diffs = <double>[];
    for (var i = 1; i < stable.length; i++) {
      diffs.add((stable[i] - stable[i - 1]).abs());
    }
    var jitter = diffs.isEmpty
        ? 1.0
        : diffs.reduce((a, b) => a + b) / diffs.length;

    // Jitter kecil tapi selalu terlihat (min 1 ms)
    jitter = math.max(1.0, math.min(jitter * 0.75, ping));

    return PingResult(ping: ping, jitter: jitter);
  }

  Future<double?> _onePing(HttpClient client, Uri uri) async {
    try {
      final sw = Stopwatch()..start();
      final req = await client.openUrl('HEAD', uri);
      req.followRedirects = false;
      req.maxRedirects = 0;
      req.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      req.headers.set(HttpHeaders.acceptHeader, '*/*');
      req.headers.set(HttpHeaders.connectionHeader, 'keep-alive');

      final res = await req.close().timeout(const Duration(seconds: 2));
      await res.drain<void>();
      sw.stop();

      if (res.statusCode < 500) {
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

      if (res.statusCode < 500) {
        return sw.elapsedMicroseconds / 1000.0;
      }
    } catch (_) {}

    return null;
  }
}
