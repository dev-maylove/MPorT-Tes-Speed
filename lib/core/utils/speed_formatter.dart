import 'package:intl/intl.dart';

class SpeedFormatter {
  /// Formats speed with automatic unit (Mbps / Gbps).
  /// Values >= 1000 Mbps are shown as Gbps.
  static String format(double mbps, {int decimals = 2, String? unit}) {
    if (mbps < 0) return '--';

    String u;
    double value;

    if (unit != null) {
      // Explicit unit requested – no auto scaling
      u = unit;
      value = mbps;
      if (unit.toLowerCase() == 'gbps') {
        value = mbps / 1000;
      }
    } else if (mbps >= 1000) {
      u = 'Gbps';
      value = mbps / 1000;
    } else {
      u = 'Mbps';
      value = mbps;
    }

    final fmt = NumberFormat('#,##0.${'0' * decimals}');
    return '${fmt.format(value)} $u';
  }

  static String formatMbps(double? value, {int decimals = 2, String? unit}) {
    if (value == null) return '--';
    return format(value, decimals: decimals, unit: unit);
  }

  /// Alias used by UI cards & tests.
  /// Auto-converts to Gbps when value >= 1000 Mbps.
  static String formatSpeed(double? value, {int decimals = 2, String? unit}) {
    if (value == null) return '--';
    return format(value, decimals: decimals, unit: unit);
  }

  static String formatLatency(double? ms, {int decimals = 0, String unit = 'ms'}) {
    if (ms == null) return '--';
    final fmt = NumberFormat(decimals == 0 ? '#,##0' : '#,##0.${'0' * decimals}');
    return '${fmt.format(ms)} $unit';
  }

  static String formatJitter(double? ms, {int decimals = 0, String unit = 'ms'}) {
    return formatLatency(ms, decimals: decimals, unit: unit);
  }

  /// Convert bytes transferred over durationSeconds to Mbps
  static double bytesToMbps(int bytes, double durationSeconds) {
    if (durationSeconds <= 0) return 0;
    return (bytes * 8) / (durationSeconds * 1000000);
  }

  static double average(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  static double median(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = List<double>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }

  /// Simple jitter = average absolute difference between consecutive samples
  static double calculateJitter(List<double> latencies) {
    if (latencies.length < 2) return 0;
    double sum = 0;
    for (var i = 1; i < latencies.length; i++) {
      sum += (latencies[i] - latencies[i - 1]).abs();
    }
    return sum / (latencies.length - 1);
  }
}
