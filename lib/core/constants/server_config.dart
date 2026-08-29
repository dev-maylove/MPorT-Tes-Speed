/// Speed test server configuration (OpenSpeedTest / Ookla-style).
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
    final base = baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    return '$base$wsPath';
  }

  static String _withQuery(String url, Map<String, String> query) {
    final uri = Uri.parse(url);
    final merged = <String, String>{
      ...uri.queryParameters,
      ...query,
    };
    return uri.replace(queryParameters: merged).toString();
  }

  static String downloadUrlBusted() {
    final n = DateTime.now().microsecondsSinceEpoch;
    // Ookla-style servers commonly accept size= (bytes to stream).
    if (downloadPath.contains('speedtest')) {
      return _withQuery(downloadUrl, {
        'size': '35000000',
        'n': '$n',
      });
    }
    return _withQuery(downloadUrl, {
      'ckSize': '100',
      'n': '$n',
    });
  }

  static String uploadUrlBusted() {
    final n = DateTime.now().microsecondsSinceEpoch;
    return _withQuery(uploadUrl, {'n': '$n'});
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

  // ── Test duration (seconds) — similar to Ookla (~10–15s) ─
  static const int downloadDurationSeconds = 15;
  static const int uploadDurationSeconds = 15;
  /// Ignore ramp-up (TCP slow-start) like Ookla / LibreSpeed.
  static const int gracePeriodSeconds = 3;

  // ── Parallelism (Ookla uses multiple concurrent streams) ─
  static const int downloadThreads = 6;
  static const int uploadThreads = 2;

  // ── Upload payload ──────────────────────────────────────
  static const int uploadPayloadMegabytes = 1;

  // ── Ping ────────────────────────────────────────────────
  static const int pingSamples = 12;
  static const int pingWarmup = 2;
  static const int pingIntervalMs = 20;
  static const int pingTrimCount = 4;

  // ── Overhead (HTTP framing / TCP) — mild, like commercial apps ─
  static const double overheadAdjustment = 1.04;

  // ── Throughput sampling ─────────────────────────────────
  /// Live gauge update interval. Final and live values use the same
  /// measured byte/time window; this interval only controls UI refresh rate.
  static const int sampleIntervalMs = 200;

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

  /// UI progress throttle (ms) — independent of sample interval.
  static const int progressThrottleMs = 360;

  const ServerConfig._();
}
