# v23 Deep Audit — Lifecycle, Network, Accuracy, Cleanup

Baseline: MPorT v23 (known-good build/signing baseline).

## Implemented

- Run-scoped operation IDs in orchestration and transfer services.
- Per-run cancellation reasons so an old run cannot consume/overwrite a new run's cancellation state.
- Scoped connectivity subscription cleanup so an old run cannot cancel a newer run's listener.
- Connectivity monitoring during active tests; Wi-Fi/mobile/ethernet/VPN path changes abort the run and prevent mixed-network results.
- Explicit lifecycle state: idle → preparing → testing → stopping → completed/failed.
- Typed error classes: cancelled, network changed, timeout, no internet, server, TLS/HTTP, unexpected.
- Immediate HTTP failure classification and one fallback-server attempt.
- Server probing cancellation before the critical test path; stale probe completion cannot clobber a newer selection.
- Download stream inactivity timeout.
- Upload/download active-window accounting based on intervals with actual byte progress instead of blindly using wall-clock duration.
- Warm-up remains excluded from throughput score.
- Robust outlier rejection for live throughput display using median/MAD filtering; final score remains aggregate bytes / active seconds to avoid biased averaging.
- WebSocket status traffic is paused during the measurement window to reduce background interference.
- Screen disposal now cancels an active test.
- Post-processing (history/notification) errors no longer convert a successful network measurement into a failed test.
- Regression tests for cancel/restart, concurrent start, network change, fallback, timeout, offline state, and throughput outliers.

## Deliberately unchanged

- v23 signing/build workflow and keystore configuration.
- Application server catalog.
- Existing UI visual design.

## Validation

- Bash syntax checks performed for project shell scripts.
- ZIP integrity checked after packaging.
- Flutter analyze/test could not be executed in this runtime because the Flutter/Dart SDK is not installed; CI remains the authoritative Flutter validation environment.
