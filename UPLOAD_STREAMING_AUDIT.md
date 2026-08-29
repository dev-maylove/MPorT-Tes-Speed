# Upload streaming audit

Baseline: MPorT-Tes-Speed-Fixed-v1.9.16-SigningHardened-v23-PerformanceUX

## Changes
- Upload uses `dart:io` `HttpClientRequest` directly instead of materializing the whole payload into `package:http` request body handling.
- Payload is written as zero-copy `Uint8List` views in 64 KiB chunks.
- `flush()` checkpoints occur every 256 KiB and after the final chunk, providing bounded backpressure and cancellation checkpoints.
- Live telemetry counts only bytes successfully flushed to the request/OS path.
- Final score commits only requests receiving a 2xx response.
- Final active transfer time is the union of successful request transfer intervals, avoiding concurrency double-counting and idle-time inflation.
- Every active `HttpClient` is tracked and force-closed on cancellation, timeout, terminal failure, or test shutdown.
- Operation IDs prevent stale workers from publishing results after restart.
- Connect, socket-idle/response, and flush operations have bounded timeouts.
- Retry is bounded and delayed to avoid retry storms.

## Deliberate accuracy boundary
`flush()` is the strongest client-side signal available from Dart's `HttpClientRequest`; it does not prove remote application-level receipt. Therefore flushed bytes are used only for live UI. Final throughput is based on requests accepted with a successful 2xx response.
