import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

/// Top-level / static entry points for [Isolate.run] / [compute].
///
/// Heavy CPU work stays off the UI isolate so GO / gauge stay responsive.

/// Build random-ish upload body of [megabytes] MiB.
Uint8List generateUploadPayloadSync(int megabytes) {
  final size = megabytes * 1024 * 1024;
  if (size <= 0) return Uint8List(0);
  final data = Uint8List(size);
  final rnd = Random().nextInt(255);
  const stride = 8192;
  for (var i = 0; i < size; i += stride) {
    final end = i + stride > size ? size : i + stride;
    for (var j = i; j < end; j++) {
      data[j] = (rnd + j) & 0xFF;
    }
  }
  return data;
}

/// Async wrapper — runs on a background isolate.
Future<Uint8List> generateUploadPayload(int megabytes) {
  return Isolate.run(() => generateUploadPayloadSync(megabytes));
}

/// Args for Ookla-style score (must be sendable across isolates).
class OoklaScoreArgs {
  final List<double> samples;
  final double topSamplePercent;
  final double overhead;
  final int measureBytes;
  final double measureSeconds;

  const OoklaScoreArgs({
    required this.samples,
    required this.topSamplePercent,
    required this.overhead,
    required this.measureBytes,
    required this.measureSeconds,
  });
}

/// Final Mbps: prefer top-% of instantaneous samples; else total/time.
double computeOoklaMbpsSync(OoklaScoreArgs args) {
  final samples = args.samples;
  var mbps = 0.0;
  if (samples.isNotEmpty) {
    final sorted = List<double>.from(samples)..sort();
    final n = sorted.length;
    var topCount = (n * args.topSamplePercent).ceil();
    if (topCount < 1) topCount = 1;
    if (topCount > n) topCount = n;
    final top = sorted.sublist(n - topCount);
    var sum = 0.0;
    for (final v in top) {
      sum += v;
    }
    mbps = sum / top.length;
  }
  if (mbps <= 0 && args.measureBytes > 0 && args.measureSeconds > 0.1) {
    mbps = args.measureBytes * 8 / args.measureSeconds / 1e6 * args.overhead;
  }
  return mbps;
}

Future<double> computeOoklaMbps(OoklaScoreArgs args) {
  // Small lists are fine on UI isolate; only offload when sampling is heavy.
  if (args.samples.length < 40) {
    return Future<double>.value(computeOoklaMbpsSync(args));
  }
  return Isolate.run(() => computeOoklaMbpsSync(args));
}
