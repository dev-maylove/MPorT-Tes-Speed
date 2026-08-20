import 'package:flutter_test/flutter_test.dart';
import 'package:mport_test_speed/features/speed_test/services/ping_service.dart';

void main() {
  test('PingResult holds values', () {
    const r = PingResult(ping: 24, jitter: 3);
    expect(r.ping, 24);
    expect(r.jitter, 3);
  });
}
