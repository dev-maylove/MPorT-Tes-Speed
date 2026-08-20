import 'package:flutter_test/flutter_test.dart';
import 'package:mport_test_speed/core/utils/speed_formatter.dart';

void main() {
  test('upload payload size', () {
    final payload = SpeedFormatter.generatePayload(1_000_000);
    expect(payload.length, 1_000_000);
  });

  test('upload speed calculation', () {
    final mbps = SpeedFormatter.bytesToMbps(10 * 1000 * 1000, 5);
    expect(mbps, closeTo(16.0, 0.1));
  });
}
