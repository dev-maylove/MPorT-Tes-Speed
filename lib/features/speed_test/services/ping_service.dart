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
  Future<PingResult> test({
    int samples = ServerConfig.pingSamples,
  }) async {
    final values = <double>[];

    for (var i = 0; i < samples; i++) {
      final stopwatch = Stopwatch()..start();

      try {
        final response = await http
            .get(
              Uri.parse(ServerConfig.downloadUrlBusted()),
              headers: ServerConfig.defaultHeaders,
            )
            .timeout(
              const Duration(seconds: ServerConfig.connectTimeoutSeconds),
            );

        stopwatch.stop();

        if (response.statusCode == 200) {
          values.add(stopwatch.elapsedMicroseconds / 1000.0);
        }
      } catch (_) {
        stopwatch.stop();
      }

      if (i < samples - 1) {
        await Future.delayed(
          const Duration(milliseconds: ServerConfig.pingIntervalMs),
        );
      }
    }

    if (values.isEmpty) {
      throw Exception('Ping gagal — server tidak merespons');
    }

    final chronological = List<double>.from(values);
    final sorted = List<double>.from(values)..sort();

    // Trim outlier (buang terendah & tertinggi)
    var working = sorted;
    final trim = ServerConfig.pingTrimCount;
    if (values.length > trim * 2 + 1) {
      working = values.sublist(trim, values.length - trim);
    }

    // Median lebih stabil daripada min/mean untuk latency
    final mid = working.length ~/ 2;
    final ping = working.length.isOdd
        ? working[mid]
        : (working[mid - 1] + working[mid]) / 2;

    // Jitter = rata-rata selisih absolut antar sampel berurutan
    final diffs = <double>[];
    for (var i = 1; i < chronological.length; i++) {
      diffs.add((chronological[i] - chronological[i - 1]).abs());
    }
    final jitter = diffs.isEmpty
        ? 0.0
        : diffs.reduce((a, b) => a + b) / diffs.length;

    return PingResult(ping: ping, jitter: jitter);
  }
}
