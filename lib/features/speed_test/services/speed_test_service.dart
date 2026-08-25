import '../../../core/constants/server_config.dart';
import '../models/speed_result.dart';
import '../models/speed_test_state.dart';
import 'download_service.dart';
import 'ping_service.dart';
import 'upload_service.dart';

class SpeedTestService {
  final PingService _pingService;
  final DownloadService _downloadService;
  final UploadService _uploadService;
  bool _cancelled = false;

  SpeedTestService({
    PingService? pingService,
    DownloadService? downloadService,
    UploadService? uploadService,
  })  : _pingService = pingService ?? PingService(),
        _downloadService = downloadService ?? DownloadService(),
        _uploadService = uploadService ?? UploadService();

  /// Call once after first frame — payload built on a background isolate.
  Future<void> warmUp() async {
    try {
      await _uploadService.warmUp();
    } catch (_) {}
  }

  /// Stop in-flight download/upload workers.
  void cancel() {
    _cancelled = true;
    _downloadService.cancel();
    _uploadService.cancel();
  }

  Future<SpeedResult> start({
    void Function(SpeedTestPhase phase, double value)? onProgress,
    bool multiConnection = true,
  }) async {
    _cancelled = false;
    final downloadThreads =
        multiConnection ? ServerConfig.downloadThreads : 1;
    final uploadThreads =
        multiConnection ? ServerConfig.uploadThreads : 1;

    onProgress?.call(SpeedTestPhase.ping, 0);

    final pingResult = await _pingService.test();
    if (_cancelled) {
      return SpeedResult(
        ping: pingResult.ping,
        jitter: pingResult.jitter,
        avgPing: pingResult.avgPing,
        maxPing: pingResult.maxPing,
        packetLossPercent: pingResult.packetLossPercent,
        download: 0,
        upload: 0,
        server: ServerConfig.serverName,
        timestamp: DateTime.now(),
      );
    }
    onProgress?.call(SpeedTestPhase.ping, pingResult.ping);

    onProgress?.call(SpeedTestPhase.download, 0);
    final downloadResult = await _downloadService.test(
      threads: downloadThreads,
      onProgress: (speed) {
        if (!_cancelled) {
          onProgress?.call(SpeedTestPhase.download, speed);
        }
      },
    );
    if (_cancelled) {
      return SpeedResult(
        ping: pingResult.ping,
        jitter: pingResult.jitter,
        avgPing: pingResult.avgPing,
        maxPing: pingResult.maxPing,
        packetLossPercent: pingResult.packetLossPercent,
        download: downloadResult.mbps,
        upload: 0,
        server: ServerConfig.serverName,
        timestamp: DateTime.now(),
      );
    }

    // Upload: do not fail the whole test if upload errors
    double uploadMbps = 0;
    onProgress?.call(SpeedTestPhase.upload, 0);
    try {
      final uploadResult = await _uploadService.test(
        threads: uploadThreads,
        onProgress: (speed) {
          if (!_cancelled) {
            onProgress?.call(SpeedTestPhase.upload, speed);
          }
        },
      );
      uploadMbps = uploadResult.mbps;
    } catch (_) {
      uploadMbps = 0;
      if (!_cancelled) {
        onProgress?.call(SpeedTestPhase.upload, 0);
      }
    }

    final result = SpeedResult(
      ping: pingResult.ping,
      jitter: pingResult.jitter,
      avgPing: pingResult.avgPing,
      maxPing: pingResult.maxPing,
      packetLossPercent: pingResult.packetLossPercent,
      download: downloadResult.mbps,
      upload: uploadMbps,
      server: ServerConfig.serverName,
      timestamp: DateTime.now(),
    );

    if (!_cancelled) {
      onProgress?.call(SpeedTestPhase.completed, 100);
    }
    return result;
  }
}
