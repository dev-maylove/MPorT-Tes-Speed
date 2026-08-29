import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../../core/constants/server_config.dart';
import '../models/speed_test_state.dart';
import '../utils/isolate_workers.dart';
import '../utils/throughput_math.dart';

class UploadResult {
  final double mbps;
  final int bytes;
  final Duration duration;
  const UploadResult({required this.mbps, required this.bytes, required this.duration});
}

/// Upload engine designed for low allocation pressure and deterministic
/// cancellation. The live counter tracks bytes flushed to the OS, while the
/// final score commits only requests whose server response was successful.
class UploadService {
  static const int _chunkBytes = 64 * 1024;
  static const int _flushEveryBytes = 256 * 1024;
  static const Duration _connectTimeout = Duration(seconds: ServerConfig.connectTimeoutSeconds);
  static const Duration _requestInactivityTimeout = Duration(seconds: ServerConfig.receiveTimeoutSeconds);
  static const Duration _retryDelay = Duration(milliseconds: 120);

  Uint8List? _cachedPayload;
  Future<Uint8List>? _warmInFlight;
  int? _warmInFlightSize;
  int _operationId = 0;
  int _payloadGeneration = 0;
  final Set<HttpClient> _activeClients = <HttpClient>{};

  void cancel() {
    _operationId++;
    for (final client in List<HttpClient>.from(_activeClients)) {
      try {
        client.close(force: true);
      } catch (_) {}
    }
    _activeClients.clear();
  }

  void releaseCache() {
    _payloadGeneration++;
    _cachedPayload = null;
    _warmInFlight = null;
    _warmInFlightSize = null;
  }

  Future<void> warmUp({int megabytes = ServerConfig.uploadPayloadMegabytes}) async {
    try {
      await _payloadAsync(megabytes);
    } catch (_) {}
  }

  Future<Uint8List> _payloadAsync(int megabytes) async {
    final size = megabytes * 1024 * 1024;
    final cached = _cachedPayload;
    if (cached != null && cached.length == size) return cached;
    final inflight = _warmInFlight;
    if (inflight != null && _warmInFlightSize == size) return inflight;

    final generation = _payloadGeneration;
    final future = generateUploadPayload(megabytes).then((data) {
      if (generation == _payloadGeneration) _cachedPayload = data;
      return data;
    });
    _warmInFlight = future;
    _warmInFlightSize = size;
    try {
      return await future;
    } finally {
      if (identical(_warmInFlight, future)) {
        _warmInFlight = null;
        _warmInFlightSize = null;
      }
    }
  }

  Future<UploadResult> test({
    Duration duration = const Duration(seconds: ServerConfig.uploadDurationSeconds),
    int threads = ServerConfig.uploadThreads,
    int payloadMegabytes = ServerConfig.uploadPayloadMegabytes,
    void Function(double mbps)? onProgress,
  }) async {
    final operationId = ++_operationId;
    final payload = await _payloadAsync(payloadMegabytes);
    if (operationId != _operationId) throw const SpeedTestCancelledException();

    final threadCount = threads.clamp(1, 6).toInt();
    final stopwatch = Stopwatch()..start();
    const grace = Duration(seconds: ServerConfig.gracePeriodSeconds);
    final deadline = duration;
    var running = true;
    var graceEnded = false;
    var acceptedBytes = 0;
    var wireBytes = 0;
    final successfulIntervals = <List<int>>[];
    var lastTickMicros = 0;
    var previousWireBytes = 0;
    var lastUiMs = 0;
    final intervals = <double>[];
    var consecutiveFailures = 0;
    SpeedTestException? terminalError;

    bool current() => operationId == _operationId;

    void sampleTick({bool force = false}) {
      if (!current()) return;
      final now = stopwatch.elapsedMicroseconds;
      if (!graceEnded && now >= grace.inMicroseconds) {
        graceEnded = true;
        lastTickMicros = now;
        // Never let bytes sent during warm-up leak into the first measured
        // interval.
        previousWireBytes = wireBytes;
      }
      if (!graceEnded) return;

      final dt = now - lastTickMicros;
      final deltaBytes = wireBytes - previousWireBytes;
      previousWireBytes = wireBytes;
      if (dt > 0 && deltaBytes > 0) {
        intervals.add(measuredMbps(deltaBytes, dt / 1e6, overhead: ServerConfig.overheadAdjustment));
        if (intervals.length > 12) intervals.removeAt(0);
      }
      lastTickMicros = now;
      if (!force && now ~/ 1000 - lastUiMs < ServerConfig.progressThrottleMs) return;
      final live = robustLiveMbps(intervals);
      if (live > 0) {
        lastUiMs = now ~/ 1000;
        onProgress?.call(live);
      }
    }

    final timer = Timer.periodic(const Duration(milliseconds: ServerConfig.sampleIntervalMs), (_) {
      if (running) sampleTick();
    });

    Future<void> worker() async {
      while (running && current() && stopwatch.elapsed < deadline) {
        HttpClient? client;
        try {
          client = HttpClient()
            ..connectionTimeout = _connectTimeout
            ..idleTimeout = _requestInactivityTimeout;
          _activeClients.add(client);
          final uri = Uri.parse(ServerConfig.uploadUrlBusted());
          final request = await client.openUrl('POST', uri).timeout(_connectTimeout);
          request.headers.contentType = ContentType.binary;
          for (final entry in ServerConfig.uploadHeaders.entries) {
            if (entry.key.toLowerCase() == 'content-type') continue;
            request.headers.set(entry.key, entry.value);
          }
          request.contentLength = payload.length;
          request.persistentConnection = true;
          request.bufferOutput = true;

          var bytesSinceFlush = 0;
          var firstWriteMicros = 0;
          var lastFlushMicros = 0;
          for (var offset = 0; offset < payload.length && running && current(); offset += _chunkBytes) {
              final end = math.min(offset + _chunkBytes, payload.length);
              final view = payload.buffer.asUint8List(
                payload.offsetInBytes + offset,
                end - offset,
              );
            request.add(view);
            final nowMicros = stopwatch.elapsedMicroseconds;
            firstWriteMicros = firstWriteMicros == 0 ? nowMicros : firstWriteMicros;
            final chunkBytes = end - offset;
            bytesSinceFlush += chunkBytes;
            if (bytesSinceFlush >= _flushEveryBytes || end == payload.length) {
              await request.flush().timeout(_requestInactivityTimeout);
              wireBytes += bytesSinceFlush;
              bytesSinceFlush = 0;
              lastFlushMicros = stopwatch.elapsedMicroseconds;
            }
          }
          if (bytesSinceFlush > 0) {
            await request.flush().timeout(_requestInactivityTimeout);
            wireBytes += bytesSinceFlush;
            bytesSinceFlush = 0;
            lastFlushMicros = stopwatch.elapsedMicroseconds;
          }
          if (!running || !current()) throw const SpeedTestCancelledException();
            final response = await request.close().timeout(_requestInactivityTimeout);
            await response.drain<void>().timeout(_requestInactivityTimeout);
            if (response.statusCode < 200 || response.statusCode >= 300) {
              consecutiveFailures++;
              if (consecutiveFailures >= 2) {
                throw SpeedTestServerException('Upload HTTP ${response.statusCode}');
              }
              continue;
            }
            consecutiveFailures = 0;
            if (current() && stopwatch.elapsed <= deadline) {
              // A successful response is the commit point. To keep the grace
              // period honest, only commit requests whose measured transfer
              // started after warm-up; a request straddling warm-up is ignored
              // rather than assigning an unknowable byte split to it.
              final activeStart = firstWriteMicros;
              final activeEnd = lastFlushMicros;
              if (activeStart >= grace.inMicroseconds &&
                  activeEnd > activeStart) {
                acceptedBytes += payload.length;
                successfulIntervals.add(<int>[activeStart, activeEnd]);
              }
            }
        } on SpeedTestCancelledException {
          if (current()) rethrow;
          break;
        } on SocketException catch (e) {
          if (!running || !current()) break;
          consecutiveFailures++;
          if (consecutiveFailures >= 3) {
            terminalError = SpeedTestTlsHttpException('Network/TLS error: ${e.message}', cause: e);
            running = false;
            _closeActiveClients();
            break;
          }
          await Future<void>.delayed(_retryDelay);
        } on TimeoutException catch (e) {
          if (!running || !current()) break;
          consecutiveFailures++;
          if (consecutiveFailures >= 3) {
            terminalError = SpeedTestTimeoutException('Upload timed out: $e');
            running = false;
            _closeActiveClients();
            break;
          }
          await Future<void>.delayed(_retryDelay);
        } on SpeedTestServerException catch (e) {
          terminalError = e;
          running = false;
          _closeActiveClients();
          break;
        } catch (e) {
          if (!running || !current()) break;
          consecutiveFailures++;
          if (consecutiveFailures >= 3) {
            terminalError = SpeedTestException(SpeedTestErrorKind.unexpected, 'Upload failed: $e', cause: e);
            running = false;
            _closeActiveClients();
            break;
          }
          await Future<void>.delayed(_retryDelay);
        } finally {
          if (client != null) {
            _activeClients.remove(client);
            try {
              client.close();
            } catch (_) {}
          }
        }
      }
    }

    try {
      final workers = List.generate(threadCount, (_) => worker());
      try {
        await Future.any(<Future<void>>[
          Future.wait(workers),
          Future<void>.delayed(duration + const Duration(milliseconds: 700)),
        ]);
      } finally {
        running = false;
        _closeActiveClients();
        try {
          await Future.wait(workers);
        } catch (_) {
          // The final classification below is based on the committed bytes
          // and terminal error; cancellation is handled by operationId.
        }
      }
    } finally {
      running = false;
      timer.cancel();
      sampleTick(force: true);
      stopwatch.stop();
      _closeActiveClients();
    }

    if (!current()) throw const SpeedTestCancelledException();
    if (terminalError != null) throw terminalError!;

    final bytes = math.max(0, acceptedBytes);
    successfulIntervals.sort((a, b) => a[0].compareTo(b[0]));
    var activeMicros = 0;
    var mergedStart = 0;
    var mergedEnd = 0;
    for (final interval in successfulIntervals) {
      if (mergedEnd == 0) {
        mergedStart = interval[0];
        mergedEnd = interval[1];
      } else if (interval[0] <= mergedEnd) {
        mergedEnd = math.max(mergedEnd, interval[1]);
      } else {
        activeMicros += mergedEnd - mergedStart;
        mergedStart = interval[0];
        mergedEnd = interval[1];
      }
    }
    if (mergedEnd > mergedStart) activeMicros += mergedEnd - mergedStart;
    final seconds = activeMicros / 1e6;
    if (bytes <= 0 || seconds <= 0) {
      throw const SpeedTestTimeoutException('Upload timed out or no data was accepted');
    }
    final mbps = measuredMbps(bytes, seconds, overhead: ServerConfig.overheadAdjustment);
    if (mbps <= 0) throw const SpeedTestServerException('Upload server returned no usable data');
    onProgress?.call(mbps);
    return UploadResult(mbps: mbps, bytes: bytes, duration: stopwatch.elapsed);
  }

  void _closeActiveClients() {
    for (final client in List<HttpClient>.from(_activeClients)) {
      try {
        client.close(force: true);
      } catch (_) {}
    }
    _activeClients.clear();
  }
}
