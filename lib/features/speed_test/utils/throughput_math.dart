import '../../../core/constants/server_config.dart';

/// Ookla-style final score: average of the fastest [topSamplePercent] samples.
double ooklaStyleMbps(List<double> samples) {
  if (samples.isEmpty) return 0;
  final sorted = List<double>.from(samples)..sort();
  final n = sorted.length;
  var topCount = (n * ServerConfig.topSamplePercent).ceil();
  if (topCount < 1) topCount = 1;
  if (topCount > n) topCount = n;
  final top = sorted.sublist(n - topCount);
  var sum = 0.0;
  for (final v in top) {
    sum += v;
  }
  return sum / top.length;
}

/// Exponential moving average for smoother live gauge (not used in final score).
double ema(double previous, double next, [double alpha = 0.35]) {
  if (previous <= 0) return next;
  return previous * (1 - alpha) + next * alpha;
}
