import 'package:http/http.dart' as http;

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
  /// Ping ringan via HEAD (tanpa unduh body).
  /// Sebelumnya GET /downloading → mengukur transfer file, hasilnya 5000–6000 ms.
  Future<PingResult> test({
    int samples = ServerConfig.pingSamples,
  }) async {
    final samplesMs = <double>[];
    final client = http.Client();

    try {
      for (var i = 0; i < samples; i++) {
        final uri = Uri.parse(
          '${ServerConfig.pingUrl}?n=${DateTime.now().microsecondsSinceEpoch}',
        );

        final ms = await _onePing(client, uri);
        if (ms != null) samplesMs.add(ms);

        if (i < samples - 1) {
          await Future.delayed(
            const Duration(milliseconds: ServerConfig.pingIntervalMs),
          );
        }
      }
    } finally {
      client.close();
    }

    if (samplesMs.isEmpty) {
      throw Exception('Ping gagal — server tidak merespons');
    }

    // Jitter dari urutan pengukuran (sebelum sort)
    final diffs = <double>[];
    for (var i = 1; i < samplesMs.length; i++) {
      diffs.add((samplesMs[i] - samplesMs[i - 1]).abs());
    }
    final jitter = diffs.isEmpty
        ? 0.0
        : diffs.reduce((a, b) => a + b) / diffs.length;

    // Median latency
    final sorted = List<double>.from(samplesMs)..sort();
    var working = sorted;
    const trim = ServerConfig.pingTrimCount;
    if (working.length > trim * 2 + 1) {
      working = working.sublist(trim, working.length - trim);
    }
    final mid = working.length ~/ 2;
    final ping = working.length.isOdd
        ? working[mid]
        : (working[mid - 1] + working[mid]) / 2;

    return PingResult(ping: ping, jitter: jitter);
  }

  Future<double?> _onePing(http.Client client, Uri uri) async {
    // 1) HEAD — ideal
    try {
      final sw = Stopwatch()..start();
      final res = await client
          .head(uri, headers: ServerConfig.defaultHeaders)
          .timeout(const Duration(seconds: 3));
      sw.stop();
      if (res.statusCode < 500) {
        return sw.elapsedMicroseconds / 1000.0;
      }
    } catch (_) {}

    // 2) GET 1 byte (Range) — fallback
    try {
      final sw = Stopwatch()..start();
      final res = await client
          .get(
            uri,
            headers: {
              ...ServerConfig.defaultHeaders,
              'Range': 'bytes=0-0',
            },
          )
          .timeout(const Duration(seconds: 3));
      sw.stop();
      if (res.statusCode < 500) {
        return sw.elapsedMicroseconds / 1000.0;
      }
    } catch (_) {}

    return null;
  }
}
