/// Konfigurasi server speed test (gaya OpenSpeedTest).
///
/// Endpoint standar:
/// - Download: GET  /downloading
/// - Upload:   POST /upload
///
/// Server aktif bisa diganti lewat [useServer] (multi-server / terdekat).
class ServerConfig {
  // ── Server aktif (bisa diubah runtime) ──────────────────
  static String baseUrl = 'https://speed2.haansiro.id';
  static String downloadPath = '/downloading';
  static String uploadPath = '/upload';
  static String pingPath = '/';
  static String serverName = 'HaaNSirO';

  static String get downloadUrl => '$baseUrl$downloadPath';
  static String get uploadUrl => '$baseUrl$uploadPath';
  static String get pingUrl => '$baseUrl$pingPath';

  static String downloadUrlBusted() =>
      '$downloadUrl?ckSize=100&n=${DateTime.now().microsecondsSinceEpoch}';

  static String uploadUrlBusted() =>
      '$uploadUrl?n=${DateTime.now().microsecondsSinceEpoch}';

  /// Ganti server aktif (dipanggil saat pilih / auto-nearest).
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

  // ── Durasi tes (detik) ──────────────────────────────────
  static const int downloadDurationSeconds = 15;
  static const int uploadDurationSeconds = 15;
  static const int gracePeriodSeconds = 2;

  // ── Parallelisme ────────────────────────────────────────
  static const int downloadThreads = 6;
  static const int uploadThreads = 6;

  // ── Payload upload ──────────────────────────────────────
  static const int uploadPayloadMegabytes = 4;

  // ── Ping ────────────────────────────────────────────────
  static const int pingSamples = 6;
  static const int pingIntervalMs = 25;
  static const int pingTrimCount = 1;

  // ── Koreksi overhead ────────────────────────────────────
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
