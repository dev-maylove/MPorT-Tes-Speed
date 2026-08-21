import '../../../core/constants/server_config.dart';
import '../models/speed_result.dart';
import '../models/test_server.dart';
import '../services/speed_test_service.dart';

class SpeedTestRepository {
  final SpeedTestService _service;
  TestServer _selected = TestServer.haansiro();

  SpeedTestRepository({SpeedTestService? service})
      : _service = service ?? SpeedTestService();

  Future<SpeedResult> runSpeedTest({
    void Function(dynamic phase, double value)? onProgress,
  }) {
    return _service.start(onProgress: onProgress);
  }

  SpeedTestService get service => _service;
  TestServer get selectedServer => _selected;

  void setServer(TestServer server) {
    _selected = server;
    ServerConfig.useServer(
      host: server.host,
      name: server.name,
      scheme: server.scheme,
      download: server.downloadPath,
      upload: server.uploadPath,
      ping: server.pingPath,
    );
  }
}
