import 'package:flutter_test/flutter_test.dart';
import 'package:mport_test_speed/features/speed_test/services/ping_service.dart';

void main() {
  test('PingResult holds latency metrics', () {
    const r = PingResult(
      ping: 24,
      jitter: 3,
      avgPing: 28,
      maxPing: 45,
      packetLossPercent: 0,
      sampleCount: 16,
    );
    expect(r.ping, 24);
    expect(r.jitter, 3);
    expect(r.avgPing, 28);
    expect(r.maxPing, 45);
    expect(r.packetLossPercent, 0);
    expect(r.sampleCount, 16);
  });
}
