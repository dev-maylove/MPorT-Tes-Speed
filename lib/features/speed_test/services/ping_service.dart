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
  /// Ping ultra-ringan:
  /// - HttpClient keep-alive (handshake hanya di warmup)
  /// - HEAD tanpa body
  /// - Warmup dibuang
  /// - Ping = minimum sample (latency terbaik)
  /// - Jitter = rata-rata selisih berurutan pada sample terbaik
  Future<PingResult> test({
    int samples = ServerConfig.pingSamples,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 3);
    client.idleTimeout = const Duration(seconds: 10);
    client.userAgent = 'MPorT-TesSpeed/1.0';
    // Jangan kompres / redirect berat
    client.autoUncompress = false;

    final samplesMs = <double>[];

    try {
      final total = samples + ServerConfig.pingWarmup;

      for (var i = 0; i < total; i++) {
        final uri = Uri.parse(
          '${ServerConfig.pingUrl}?n=${DateTime.now().microsecondsSinceEpoch}',
        );

        final ms = await _onePing(client, uri);
        // Buang warmup (TCP/TLS handshake biasanya sample pertama)
        if (i >= ServerConfig.pingWarmup && ms != null) {
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

    // ── Ping: ambil nilai TERKECIL (best latency) ──
    final sorted = List<double>.from(samplesMs)..sort();
    // Buang outlier tertinggi
    var working = sorted;
    const trim = ServerConfig.pingTrimCount;
    if (working.length > trim + 1) {
      working = working.sublist(0, working.length - trim);
    }
    final ping = working.reduce(math.min);

    // ── Jitter: selisih berurutan pada sample yang sudah distabilkan ──
    // Pakai urutan asli, tapi hanya sample ≤ percentile 75 agar jitter kecil & stabil
    final threshold = sorted[(sorted.length * 0.75).floor().clamp(0, sorted.length - 1)];
    final stable = samplesMs.where((v) => v <= threshold).toList();
    final diffs = <double>[];
    for (var i = 1; i < stable.length; i++) {
      diffs.add((stable[i] - stable[i - 1]).abs());
    }
    var jitter = diffs.isEmpty
        ? 0.0
        : diffs.reduce((a, b) => a + b) / diffs.length;

    // Jitter tidak boleh lebih besar dari ping (masuk akal secara UX)
    if (jitter > ping) jitter = ping;
    // Floor sangat kecil agar UI bersih
    if (jitter < 0.5) jitter = 0;

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
      // Drain agar koneksi bisa di-reuse
      await res.drain<void>();
      sw.stop();

      if (res.statusCode < 500) {
        return sw.elapsedMicroseconds / 1000.0;
      }
    } catch (_) {}

    // Fallback: GET 0 byte
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
