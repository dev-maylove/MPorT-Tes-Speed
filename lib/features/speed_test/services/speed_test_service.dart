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

  SpeedTestService({
    PingService? pingService,
    DownloadService? downloadService,
    UploadService? uploadService,
  })  : _pingService = pingService ?? PingService(),
        _downloadService = downloadService ?? DownloadService(),
        _uploadService = uploadService ?? UploadService();

  Future<SpeedResult> start({
    void Function(SpeedTestPhase phase, double value)? onProgress,
  }) async {
    onProgress?.call(SpeedTestPhase.ping, 0);

    final pingResult = await _pingService.test();
    onProgress?.call(SpeedTestPhase.ping, pingResult.ping);

    onProgress?.call(SpeedTestPhase.download, 0);
    final downloadResult = await _downloadService.test(
      onProgress: (speed) {
        onProgress?.call(SpeedTestPhase.download, speed);
      },
    );

    // Upload: do not fail the whole test if upload errors
    double uploadMbps = 0;
    onProgress?.call(SpeedTestPhase.upload, 0);
    try {
      final uploadResult = await _uploadService.test(
        onProgress: (speed) {
          onProgress?.call(SpeedTestPhase.upload, speed);
        },
      );
      uploadMbps = uploadResult.mbps;
    } catch (_) {
      // Upload failed — still keep ping + download results
      uploadMbps = 0;
      onProgress?.call(SpeedTestPhase.upload, 0);
    }

    final result = SpeedResult(
      ping: pingResult.ping,
      jitter: pingResult.jitter,
      download: downloadResult.mbps,
      upload: uploadMbps,
      server: ServerConfig.serverName,
      timestamp: DateTime.now(),
    );

    onProgress?.call(SpeedTestPhase.completed, 100);
    return result;
  }
}
