import 'package:flutter_test/flutter_test.dart';
import 'package:mport_test_speed/core/utils/speed_formatter.dart';
import 'package:mport_test_speed/features/speed_test/utils/throughput_math.dart';

void main() {
  test('download speed calculation helper', () {
    // 25 MB in 10 seconds = 20 Mbps using decimal megabits.
    final mbps = SpeedFormatter.bytesToMbps(25 * 1000 * 1000, 10);
    expect(mbps, closeTo(20.0, 0.1));
  });

  test('live and final throughput use the same measured-window formula', () {
    final live = measuredMbps(25 * 1000 * 1000, 10, overhead: 1.04);
    final finalValue = measuredMbps(25 * 1000 * 1000, 10, overhead: 1.04);

    expect(live, finalValue);
    expect(live, closeTo(20.8, 0.001));
  });

  test('throughput remains zero for non-finite seconds', () {
    expect(measuredMbps(1000, double.nan), 0);
    expect(measuredMbps(1000, double.infinity), 0);
  });

  test('invalid throughput inputs return zero', () {
    expect(measuredMbps(0, 10), 0);
    expect(measuredMbps(1000, 0), 0);
    expect(measuredMbps(1000, -1), 0);
  });
}

