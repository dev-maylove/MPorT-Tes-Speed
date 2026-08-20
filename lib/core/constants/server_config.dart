/// Konfigurasi server speed test HaaNSirO (gaya OpenSpeedTest).
///
/// Endpoint:
/// - Download: GET  /downloading
/// - Upload:   POST /upload
class ServerConfig {
  // ── Server ──────────────────────────────────────────────
  static const String baseUrl = 'https://speed2.haansiro.id';
  static const String downloadPath = '/downloading';
  static const String uploadPath = '/upload';
  static const String serverName = 'HaaNSirO';

  static String get downloadUrl => '$baseUrl$downloadPath';
  static String get uploadUrl => '$baseUrl$uploadPath';

  /// URL dengan cache-buster unik (cegah CDN/proxy cache).
  static String downloadUrlBusted() =>
      '$downloadUrl?ckSize=100&n=${DateTime.now().microsecondsSinceEpoch}';

  static String uploadUrlBusted() =>
      '$uploadUrl?n=${DateTime.now().microsecondsSinceEpoch}';

  // ── Durasi tes (detik) ──────────────────────────────────
  /// Total jendela pengukuran download.
  static const int downloadDurationSeconds = 15;

  /// Total jendela pengukuran upload.
  static const int uploadDurationSeconds = 15;

  /// Detik awal yang diabaikan (TCP slow-start / ramp-up).
  /// OpenSpeedTest mengabaikan ~2–3 detik pertama.
  static const int gracePeriodSeconds = 2;

  // ── Parallelisme ────────────────────────────────────────
  /// Jumlah stream paralel download.
  /// 4–8 ideal untuk koneksi rumah; 6 seimbang CPU vs akurasi.
  static const int downloadThreads = 6;

  /// Jumlah stream paralel upload.
  static const int uploadThreads = 6;

  // ── Payload upload ──────────────────────────────────────
  /// Ukuran chunk upload per request (MB).
  /// 2–4 MB: lebih responsif di koneksi lambat.
  /// 5–8 MB: lebih efisien di koneksi cepat (>100 Mbps).
  static const int uploadPayloadMegabytes = 4;

  // ── Ping ────────────────────────────────────────────────
  static const int pingSamples = 12;

  /// Jeda antar sampel ping (ms) agar tidak flood server.
  static const int pingIntervalMs = 40;

  /// Buang N sampel terendah & tertinggi sebelum hitung median.
  static const int pingTrimCount = 1;

  // ── Koreksi overhead ────────────────────────────────────
  /// Faktor koreksi protokol HTTP (header, TLS, TCP ACKs).
  /// OpenSpeedTest ≈ 1.04–1.08. 1.06 cocok untuk HTTPS.
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

  // ── Progress throttle ───────────────────────────────────
  /// Minimal interval update UI (ms) agar tidak spam setState.
  static const int progressThrottleMs = 150;

  const ServerConfig._();
}
