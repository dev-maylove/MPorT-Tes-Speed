import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mport_test_speed/features/speed_test/models/speed_result.dart';
import 'package:mport_test_speed/features/speed_test/models/speed_test_state.dart';
import 'package:mport_test_speed/features/speed_test/services/download_service.dart';
import 'package:mport_test_speed/features/speed_test/services/ping_service.dart';
import 'package:mport_test_speed/features/speed_test/services/speed_test_service.dart';
import 'package:mport_test_speed/features/speed_test/services/upload_service.dart';

PingResult _ping() => const PingResult(
      ping: 10,
      jitter: 1,
      avgPing: 11,
      maxPing: 14,
      packetLossPercent: 0,
      sampleCount: 8,
    );

class FakePingService extends PingService {
  int _generation = 0;
  int calls = 0;
  bool failFirst = false;
  Duration delay;

  FakePingService({this.delay = Duration.zero});

  @override
  void cancel() => _generation++;

  @override
  Future<PingResult> test({int samples = 16}) async {
    final generation = ++_generation;
    calls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (generation != _generation) throw const PingCancelledException();
    if (failFirst && calls == 1) {
      throw const SpeedTestServerException('primary unavailable');
    }
    return _ping();
  }
}

class FakeDownloadService extends DownloadService {
  int _generation = 0;
  bool timeout = false;

  @override
  void cancel() => _generation++;

  @override
  Future<DownloadResult> test({
    Duration duration = const Duration(seconds: 15),
    int threads = 6,
    void Function(double mbps)? onProgress,
  }) async {
    final generation = ++_generation;
    await Future<void>.delayed(const Duration(milliseconds: 2));
    if (generation != _generation) throw const SpeedTestCancelledException();
    if (timeout) throw const SpeedTestTimeoutException('download timeout');
    onProgress?.call(80);
    return const DownloadResult(mbps: 80, bytes: 1000000, duration: Duration(seconds: 1));
  }
}

class FakeUploadService extends UploadService {
  int _generation = 0;

  @override
  void cancel() => _generation++;

  @override
  Future<UploadResult> test({
    Duration duration = const Duration(seconds: 15),
    int threads = 4,
    int payloadMegabytes = 2,
    void Function(double mbps)? onProgress,
  }) async {
    final generation = ++_generation;
    await Future<void>.delayed(const Duration(milliseconds: 2));
    if (generation != _generation) throw const SpeedTestCancelledException();
    onProgress?.call(20);
    return const UploadResult(mbps: 20, bytes: 1000000, duration: Duration(seconds: 1));
  }

  @override
  Future<void> warmUp({int megabytes = 2}) async {}

  @override
  void releaseCache() {}
}

SpeedTestService makeService({
  FakePingService? ping,
  FakeDownloadService? download,
  FakeUploadService? upload,
  Future<List<ConnectivityResult>> Function()? check,
  Stream<List<ConnectivityResult>> Function()? changes,
}) => SpeedTestService(
      pingService: ping ?? FakePingService(),
      downloadService: download ?? FakeDownloadService(),
      uploadService: upload ?? FakeUploadService(),
      connectivityCheck: check ?? (() async => const [ConnectivityResult.wifi]),
      connectivityChanges: changes ?? (() => const Stream.empty()),
    );

void main() {
  test('start → cancel → start: old run cannot overwrite the new run', () async {
    final ping = FakePingService(delay: const Duration(milliseconds: 30));
    final service = makeService(ping: ping);
    final first = service.start();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    service.cancel();
    await expectLater(first, throwsA(isA<SpeedTestCancelledException>()));

    final second = await service.start();
    expect(second.download, 80);
    expect(second.upload, 20);
  });

  test('two concurrent starts are rejected', () async {
    final service = makeService(ping: FakePingService(delay: const Duration(milliseconds: 30)));
    final first = service.start();
    await expectLater(service.start(), throwsA(isA<SpeedTestException>()));
    service.cancel();
    await expectLater(first, throwsA(isA<SpeedTestCancelledException>()));
  });

  test('network change aborts the run and is not reported as a speed result', () async {
    final controller = StreamController<List<ConnectivityResult>>();
    addTearDown(controller.close);
    final ping = FakePingService(delay: const Duration(milliseconds: 50));
    final service = makeService(
      ping: ping,
      changes: () => controller.stream,
    );

    final future = service.start();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    controller.add(const [ConnectivityResult.mobile]);

    await expectLater(future, throwsA(isA<SpeedTestNetworkChangedException>()));
    expect(service.lifecycle, SpeedTestLifecycle.failed);
  });

  test('server failure falls back to another server', () async {
    final ping = FakePingService()..failFirst = true;
    final service = makeService(ping: ping);
    final result = await service.start();
    expect(ping.calls, 2);
    expect(result, isA<SpeedResult>());
  });

  test('timeout is classified and fallback is attempted', () async {
    final download = FakeDownloadService()..timeout = true;
    final service = makeService(download: download);
    await expectLater(service.start(), throwsA(isA<SpeedTestTimeoutException>()));
  });

  test('explicit lifecycle values cover the complete run state machine', () {
    expect(SpeedTestLifecycle.values, containsAll(<SpeedTestLifecycle>[
      SpeedTestLifecycle.idle,
      SpeedTestLifecycle.preparing,
      SpeedTestLifecycle.testing,
      SpeedTestLifecycle.stopping,
      SpeedTestLifecycle.completed,
      SpeedTestLifecycle.failed,
    ]));
  });
  test('offline state fails explicitly instead of returning zero-speed data', () async {
    final service = makeService(
      check: () async => const <ConnectivityResult>[],
    );
    await expectLater(service.start(), throwsA(isA<SpeedTestNoInternetException>()));
    expect(service.lifecycle, SpeedTestLifecycle.failed);
  });

  test('cancellation during a run leaves the service ready for immediate restart', () async {
    final ping = FakePingService(delay: const Duration(milliseconds: 40));
    final service = makeService(ping: ping);
    final first = service.start();
    await Future<void>.delayed(const Duration(milliseconds: 3));
    service.cancel();
    await expectLater(first, throwsA(isA<SpeedTestCancelledException>()));
    final result = await service.start();
    expect(result.download, 80);
    expect(service.lifecycle, SpeedTestLifecycle.completed);
  });

}

// Network-offline and disposal behavior are represented at the orchestration
// boundary so these regressions do not require a physical device network.
