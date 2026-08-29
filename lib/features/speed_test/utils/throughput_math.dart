import 'dart:math' as math;

/// Aggregate throughput for the exact active transfer window.
double measuredMbps(int bytes, double seconds, {double overhead = 1.0}) {
  if (bytes <= 0 || !seconds.isFinite || seconds <= 0) return 0;
  final value = bytes * 8 / seconds / 1e6 * overhead;
  return value.isFinite && value > 0 ? value : 0;
}

/// Robustly smooth interval throughput samples for the live gauge.
///
/// This does not alter the final byte/time score. It only removes transient
/// spikes/drops caused by packet batching, scheduler stalls, or a single slow
/// interval so the UI does not report a misleading instantaneous speed.
double robustLiveMbps(List<double> samples) {
  final valid = samples.where((v) => v.isFinite && v > 0).toList();
  if (valid.isEmpty) return 0;
  if (valid.length < 3) return valid.last;

  final sorted = List<double>.from(valid)..sort();
  final median = sorted[sorted.length ~/ 2];
  final deviations = sorted.map((v) => (v - median).abs()).toList()..sort();
  final mad = deviations[deviations.length ~/ 2];
  final tolerance = math.max(median * 0.35, mad * 3.0);
  final filtered = valid.where((v) => (v - median).abs() <= tolerance).toList();
  if (filtered.isEmpty) return median;
  return filtered.reduce((a, b) => a + b) / filtered.length;
}

/// Return the mean of valid instantaneous samples.
double ooklaStyleMbps(List<double> samples) {
  final valid = samples.where((v) => v.isFinite && v > 0).toList();
  if (valid.isEmpty) return 0;
  return valid.reduce((a, b) => a + b) / valid.length;
}

double ema(double previous, double next, [double alpha = 0.35]) {
  if (previous <= 0) return next;
  return previous * (1 - alpha) + next * alpha;
}
