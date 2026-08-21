import 'package:intl/intl.dart';

/// Format & perhitungan kecepatan.
class SpeedFormatter {
  static final NumberFormat _format = NumberFormat('#,##0.00');
  static final NumberFormat _latencyFormat = NumberFormat('#,##0');

  /// (bytes * 8) / (durationSeconds * 1_000_000) = Mbps
  static double bytesToMbps(int bytes, double durationSeconds) {
    if (durationSeconds <= 0) return 0.0;
    return (bytes * 8) / (durationSeconds * 1_000_000);
  }

  static double bpsToMbps(double bitsPerSecond) => bitsPerSecond / 1_000_000;

  static String formatSpeed(double mbps, {String unit = 'Mbps'}) {
    if (mbps >= 1000) return '${_format.format(mbps / 1000)} Gbps';
    if (mbps < 1 && mbps > 0) return '${_format.format(mbps * 1000)} Kbps';
    return '${_format.format(mbps)} $unit';
  }

  static String formatLatency(double ms) => '${_latencyFormat.format(ms)} ms';

  static String formatJitter(double ms) => '${_format.format(ms)} ms';

  static double average(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  static double median(List<double> values) {
    if (values.isEmpty) return 0.0;
    final sorted = List<double>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }

  static double calculateJitter(List<double> latencies) {
    if (latencies.length < 2) return 0.0;
    double sum = 0.0;
    for (int i = 1; i < latencies.length; i++) {
      sum += (latencies[i] - latencies[i - 1]).abs();
    }
    return sum / (latencies.length - 1);
  }

  static double percentile(List<double> values, double p) {
    if (values.isEmpty) return 0.0;
    final sorted = List<double>.from(values)..sort();
    final index = (p / 100) * (sorted.length - 1);
    final lower = index.floor();
    final upper = index.ceil();
    if (lower == upper) return sorted[lower];
    final weight = index - lower;
    return sorted[lower] * (1 - weight) + sorted[upper] * weight;
  }

  static List<int> generatePayload(int sizeInBytes) {
    return List<int>.filled(sizeInBytes, 0x41);
  }
}
