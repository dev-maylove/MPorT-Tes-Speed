class AppConstants {
  static const String appName = 'MPorT Go';
  /// Keep in sync with pubspec.yaml version (name+build).
  static const String appVersion = '1.9.15';
  static const String appBuild = '35';

  static const String defaultSpeedUnit = 'Mbps';
  static const String defaultLatencyUnit = 'ms';

  static const int defaultPingCount = 10;
  static const int defaultDownloadDurationSeconds = 10;
  static const int defaultUploadDurationSeconds = 10;
  static const int connectionTimeoutSeconds = 15;

  /// Parallel connections (OpenSpeedTest-style).
  static const int parallelConnections = 4;

  static const int maxHistoryItems = 50;

  static const Duration gaugeAnimationDuration = Duration(milliseconds: 800);
}
