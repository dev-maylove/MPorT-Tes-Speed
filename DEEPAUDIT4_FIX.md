# Deep Audit 4 — CI Fix

Fixed `download_service.dart` for Flutter/Dart 3.13 analysis:
- Added `dart:io` for `SocketException`.
- Handles `SocketException` explicitly before `TimeoutException`.
- Preserves cancellation/run-id checks and existing retry behavior.
- No signing workflow changes.

The uploaded CI log showed `SocketException` was not recognized as a type and the catch ordering was reported as unreachable. The package baseline is UploadStreaming4.
