import 'package:intl/intl.dart';

class SpeedFormatter {
  static String format(double mbps, {int decimals = 1}) {
    if (mbps < 0) return '--';
    final fmt = NumberFormat('#,##0.${'0' * decimals}');
    return '${fmt.format(mbps)} Mbps';
  }

  static String formatMbps(double? value, {int decimals = 1}) {
    if (value == null) return '--';
    return format(value, decimals: decimals);
  }

  /// Alias used by UI cards
  static String formatSpeed(double? value, {int decimals = 1}) {
    if (value == null) return '--';
    return format(value, decimals: decimals);
  }

  static String formatLatency(double? ms, {int decimals = 0}) {
    if (ms == null) return '--';
    final fmt = NumberFormat(decimals == 0 ? '#,##0' : '#,##0.${'0' * decimals}');
    return '${fmt.format(ms)} ms';
  }

  static String formatJitter(double? ms, {int decimals = 0}) {
    return formatLatency(ms, decimals: decimals);
  }

  /// Convert bytes transferred over durationSeconds to Mbps
  static double bytesToMbps(int bytes, double durationSeconds) {
    if (durationSeconds <= 0) return 0;
    // bytes * 8 / 1_000_000 = megabits, then / seconds
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
