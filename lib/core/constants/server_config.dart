/// Speed test server configuration (OpenSpeedTest-style).
///
/// Standard endpoints:
/// - Download: GET  /downloading
/// - Upload:   POST /upload
///
/// Active server can be changed via [useServer] (multi-server / nearest).
class ServerConfig {
  // ── Active server (runtime-switchable) ──────────────────
  static String baseUrl = 'http://ookla.haansiro.net:8080';
  static String downloadPath = '/speedtest/download';
  static String uploadPath = '/speedtest/upload.php';
  static String pingPath = '/speedtest/latency.txt';
  static String serverName = 'HaaNSirO';

  static String get downloadUrl => '$baseUrl$downloadPath';
  static String get uploadUrl => '$baseUrl$uploadPath';
  static String get pingUrl => '$baseUrl$pingPath';

  /// Lightweight server status / health probe (same host as ping).
  static String get statusUrl => pingUrl;

  /// Real-time WebSocket (status / latency).
  static String wsPath = '/ws';
  static String get wsUrl {
    final base = baseUrl.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
    return '$base$wsPath';
  }

  static String downloadUrlBusted() {
    final n = DateTime.now().microsecondsSinceEpoch;
    // Ookla-style vs OpenSpeedTest
    if (downloadPath.contains('speedtest')) {
      return '$downloadUrl?size=25000000&n=$n';
    }
    return '$downloadUrl?ckSize=100&n=$n';
  }

  static String uploadUrlBusted() {
    final n = DateTime.now().microsecondsSinceEpoch;
    final sep = uploadUrl.contains('?') ? '&' : '?';
    return '$uploadUrl${sep}n=$n';
  }

  /// Switch active server (called on select / auto-nearest).
  static void useServer({
    required String host,
    required String name,
    String scheme = 'https',
    String download = '/downloading',
    String upload = '/upload',
    String ping = '/',
  }) {
    final h = host.replaceFirst(RegExp(r'^https?://'), '');
    baseUrl = '$scheme://$h';
    serverName = name;
    downloadPath = download;
    uploadPath = upload;
    pingPath = ping;
  }

  // ── Test duration (seconds) ─────────────────────────────
  static const int downloadDurationSeconds = 15;
  static const int uploadDurationSeconds = 15;
  static const int gracePeriodSeconds = 2;

  // ── Parallelism ─────────────────────────────────────────
  static const int downloadThreads = 6;
  static const int uploadThreads = 4;

  // ── Upload payload ──────────────────────────────────────
  static const int uploadPayloadMegabytes = 1;

  // ── Ping (lightweight, aim for lowest result) ───────────
  static const int pingSamples = 16;
  static const int pingWarmup = 3;
  static const int pingIntervalMs = 10;
  static const int pingTrimCount = 4;

  // ── Overhead correction ─────────────────────────────────
  static const double overheadAdjustment = 1.06;

  // ── Timeout ─────────────────────────────────────────────
  static const int connectTimeoutSeconds = 10;
  static const int receiveTimeoutSeconds = 20;

  // ── Headers ─────────────────────────────────────────────
  static const Map<String, String> defaultHeaders = {
    'User-Agent': 'MPorT-TesSpeed/1.0',
    'Accept': '*/*',
    'Cache-Control': 'no-cache, no-store, must-revalidate',
    'Pragma': 'no-cache',
    'Connection': 'keep-alive',
  };

  static const Map<String, String> uploadHeaders = {
    ...defaultHeaders,
    'Content-Type': 'application/octet-stream',
  };

  static const int progressThrottleMs = 150;

  const ServerConfig._();
}
