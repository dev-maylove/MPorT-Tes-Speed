import 'package:flutter_test/flutter_test.dart';
import 'package:mport_test_speed/features/speed_test/utils/throughput_math.dart';

void main() {
  test('live throughput rejects an isolated outlier', () {
    final value = robustLiveMbps([100, 102, 98, 1000, 101]);
    expect(value, greaterThan(95));
    expect(value, lessThan(110));
  });

  test('live throughput does not include warm-up bytes in first interval', () {
    // This is a regression invariant for the upload/download samplers: the
    // first measured interval must start with the post-warm-up byte counter.
    expect(measuredMbps(10 * 1000 * 1000, 1), closeTo(80, 0.001));
  });

  test('aggregate score uses the actual active transfer window', () {
    expect(measuredMbps(12 * 1000 * 1000, 1), closeTo(96, 0.001));
    expect(measuredMbps(12 * 1000 * 1000, 2), closeTo(48, 0.001));
  });
}
