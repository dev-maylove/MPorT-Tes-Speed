import 'package:flutter_test/flutter_test.dart';
import 'package:mport_test_speed/core/utils/speed_formatter.dart';

void main() {
  group('SpeedFormatter', () {
    test('bytesToMbps', () {
      expect(SpeedFormatter.bytesToMbps(1250000, 1.0), closeTo(10.0, 0.01));
      expect(SpeedFormatter.bytesToMbps(1000, 0), 0.0);
    });

    test('average & median', () {
      expect(SpeedFormatter.average([10, 20, 30]), 20.0);
      expect(SpeedFormatter.median([1, 3, 2]), 2.0);
      expect(SpeedFormatter.median([1, 2, 3, 4]), 2.5);
    });

    test('jitter', () {
      expect(SpeedFormatter.calculateJitter([10, 20, 15]), closeTo(7.5, 0.01));
    });

    test('formatSpeed', () {
      expect(SpeedFormatter.formatSpeed(42.8), contains('42.80'));
      expect(SpeedFormatter.formatSpeed(1500), contains('Gbps'));
    });
  });
}
