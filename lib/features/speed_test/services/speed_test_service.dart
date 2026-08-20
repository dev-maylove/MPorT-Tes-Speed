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

    onProgress?.call(SpeedTestPhase.upload, 0);
    final uploadResult = await _uploadService.test(
      onProgress: (speed) {
        onProgress?.call(SpeedTestPhase.upload, speed);
      },
    );

    final result = SpeedResult(
      ping: pingResult.ping,
      jitter: pingResult.jitter,
      download: downloadResult.mbps,
      upload: uploadResult.mbps,
      server: ServerConfig.serverName,
      timestamp: DateTime.now(),
    );

    onProgress?.call(SpeedTestPhase.completed, 100);
    return result;
  }
}
