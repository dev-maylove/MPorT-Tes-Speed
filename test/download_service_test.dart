import 'package:flutter_test/flutter_test.dart';
import 'package:mport_test_speed/core/utils/speed_formatter.dart';

void main() {
  test('download speed calculation helper', () {
    // 25 MB in 10 seconds ≈ 20 Mbps
    final mbps = SpeedFormatter.bytesToMbps(25 * 1000 * 1000, 10);
    expect(mbps, closeTo(20.0, 0.1));
  });
}
