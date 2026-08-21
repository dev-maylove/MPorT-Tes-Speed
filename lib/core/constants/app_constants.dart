class AppConstants {
  static const String appName = 'MPorT Tes Speed';
  static const String appVersion = '1.5.0';
  static const String appBuild = '1';

  static const String defaultSpeedUnit = 'Mbps';
  static const String defaultLatencyUnit = 'ms';

  static const int defaultPingCount = 10;
  static const int defaultDownloadDurationSeconds = 10;
  static const int defaultUploadDurationSeconds = 10;
  static const int connectionTimeoutSeconds = 15;

  /// Jumlah koneksi paralel (gaya OpenSpeedTest)
  static const int parallelConnections = 4;

  static const int maxHistoryItems = 100;

  static const Duration gaugeAnimationDuration = Duration(milliseconds: 800);
}
