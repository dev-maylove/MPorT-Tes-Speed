/// Return the mean of valid instantaneous samples.
///
/// This helper is intended for diagnostics/live metrics. Final speed results
/// are calculated from total measured bytes and elapsed time.
double ooklaStyleMbps(List<double> samples) {
  final valid = samples.where((v) => v.isFinite && v > 0).toList();
  if (valid.isEmpty) return 0;
  var sum = 0.0;
  for (final value in valid) {
    sum += value;
  }
  return sum / valid.length;
}

/// Exponential moving average for smoother live gauge (not used in final score).
double ema(double previous, double next, [double alpha = 0.35]) {
  if (previous <= 0) return next;
  return previous * (1 - alpha) + next * alpha;
}
