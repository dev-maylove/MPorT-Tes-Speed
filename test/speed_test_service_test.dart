import 'package:flutter_test/flutter_test.dart';
import 'package:mport_test_speed/features/speed_test/models/speed_result.dart';
import 'package:mport_test_speed/features/speed_test/models/speed_test_state.dart';
import 'package:mport_test_speed/features/speed_test/models/test_server.dart';

void main() {
  group('SpeedResult', () {
    test('constructs correctly', () {
      final r = SpeedResult(
        ping: 24.5,
        jitter: 3.2,
        download: 42.8,
        upload: 18.6,
        server: 'HaaNSirO',
        timestamp: DateTime(2026, 8, 20),
      );
      expect(r.ping, 24.5);
      expect(r.download, 42.8);
      expect(r.server, 'HaaNSirO');
    });

    test('json roundtrip', () {
      final original = SpeedResult(
        ping: 24.5,
        jitter: 3.2,
        download: 42.8,
        upload: 18.6,
        server: 'HaaNSirO',
        timestamp: DateTime(2026, 8, 20, 10, 0, 0),
      );
      final restored = SpeedResult.fromJson(original.toJson());
      expect(restored.ping, original.ping);
      expect(restored.jitter, original.jitter);
      expect(restored.download, original.download);
      expect(restored.upload, original.upload);
      expect(restored.server, original.server);
    });
  });

  group('SpeedTestPhase', () {
    test('has expected values', () {
      expect(SpeedTestPhase.values.length, 6);
      expect(SpeedTestPhase.idle.name, 'idle');
      expect(SpeedTestPhase.completed.name, 'completed');
    });
  });

  group('TestServer', () {
    test('haansiro default', () {
      final s = TestServer.haansiro();
      expect(s.isDefault, true);
      expect(s.host, 'speed2.haansiro.id');
    });
  });
}
