/// Calculate throughput from the exact measured byte/time window used by the UI and final result.
///
/// [bytes] is the amount transferred during the measurement window and [seconds]
/// is the elapsed time for that same window. The same function is deliberately
/// used for live gauge updates and the final score so the needle cannot drift
/// away from the reported result because of different formulas.
double measuredMbps(int bytes, double seconds, {double overhead = 1.0}) {
  if (bytes <= 0 || !seconds.isFinite || seconds <= 0) return 0;
  final value = bytes * 8 / seconds / 1e6 * overhead;
  return value.isFinite && value > 0 ? value : 0;
}


/// Return the mean of valid instantaneous samples.
///
/// Retained for diagnostics/live metrics. Final speed results do not use this
/// statistic because it can disagree with the actual measured byte/time total.
double ooklaStyleMbps(List<double> samples) {
  final valid = samples.where((v) => v.isFinite && v > 0).toList();
  if (valid.isEmpty) return 0;
  var sum = 0.0;
  for (final value in valid) {
    sum += value;
  }
  return sum / valid.length;
}

/// Exponential moving average for diagnostics.
double ema(double previous, double next, [double alpha = 0.35]) {
  if (previous <= 0) return next;
  return previous * (1 - alpha) + next * alpha;
}
