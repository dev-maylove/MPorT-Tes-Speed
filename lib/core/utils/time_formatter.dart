class TimeFormatter {
  static String formatDuration(Duration d) {
    if (d.inMilliseconds < 1000) return '${d.inMilliseconds} ms';
    return '${(d.inMilliseconds / 1000).toStringAsFixed(1)} s';
  }

  static String formatSeconds(double seconds) {
    if (seconds < 1) return '${(seconds * 1000).toStringAsFixed(0)} ms';
    return '${seconds.toStringAsFixed(1)} s';
  }
}
