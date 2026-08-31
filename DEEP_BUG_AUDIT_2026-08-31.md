# Deep Bug Audit — MPorT Tes Speed / MPorT Go
**Date:** 2026-08-31  
**Baseline archive:** MPorT-Tes-Speed.zip

## Summary

Deep static review of the Flutter speed-test engine, UI lifecycle, Android signing, and CI.  
Previous audits (v1–v23) had already fixed many accuracy, cancellation, and CI issues. This pass focused on remaining correctness and security defects.

## Critical — Fixed

### 1. Release signing material committed in the archive
**Severity:** Critical (security)

The ZIP still contained:
- `android/key.properties` (plaintext `storePassword` / `keyPassword` = `Optionso@1212`)
- `android/mport_tes_keystore.jks`
- `android/app/mport-release-key.jks`
- `android/app/mport_tes_keystore.jks`
- `android/keystore_release_base64.txt`
- `android/keystore_tes_base64.txt`

`.gitignore` already excluded these patterns, but the archive was packaged with the files present.  
**Action taken:** All of the above files were deleted from the working tree.

**Required follow-up (cannot be done in this environment):**
- Treat the previous keystore + password as compromised.
- Generate a new release keystore.
- Store only Base64 + passwords in GitHub Actions secrets (`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`).
- Never re-commit signing material.

### 2. Shared failure counters across parallel upload/download workers
**Severity:** High (correctness / false negatives)

`UploadService` used a single shared `consecutiveFailures` counter.  
`DownloadService` used a single shared `httpFailures` counter.

Because workers interleave on the same isolate event loop, a failure on one stream could increment the global counter and abort the entire test even when other streams were healthy and transferring data. This produced unnecessary timeouts / server errors on flaky paths and discarded valid measured bytes.

**Fix:**
- Failure budgets are now **per-worker**.
- A worker that exceeds its own budget stops itself only.
- A terminal error is kept only as a fallback.
- Final scoring prefers successful accepted/measured bytes; terminal errors are thrown only when no useful data was collected.

### 3. Upload transfer interval start was late
**Severity:** Low–Medium (accuracy)

`transferStartMicros` was set on the first successful `flush()`, not when the first chunk was queued. That shortened the measured active interval and slightly inflated reported Mbps.

**Fix:** Set `transferStartMicros` on the first `request.add(...)` of the request.

## Already solid (verified, no change)

- Run-id / operation-id isolation so cancelled tests cannot publish results.
- Connectivity change aborts the active run.
- Upload final score uses only 2xx-accepted requests and merges concurrent intervals (no double-counting of wall time).
- Download/upload live gauges use robust interval filtering; final scores use measured byte/time windows (no “fastest 10%” overstatement).
- Ping uses chronological samples for jitter; primary ping is the minimum measured RTT (no arbitrary 0.82 correction).
- Grace period excludes TCP slow-start from the scored window.
- Payload generation runs off the UI isolate; cache is released on cancellation / run end.
- Release builds refuse to sign with debug keys when `key.properties` / keystore is missing.
- CI reconstructs the keystore from secrets and verifies APK/AAB signatures.

## Residual / environmental notes

- Flutter/Dart SDK is not installed in this sandbox, so `flutter analyze` / `flutter test` could not be executed here. CI remains the authoritative checker.
- `usesCleartextTraffic="true"` is intentional for the default HTTP Ookla-style host; HTTPS servers in the catalog still use TLS.
- History persistence is best-effort and race-tolerant for single-user local use (max 50 entries).

## Files changed in this pass

- Deleted: all keystore / `key.properties` / base64 key material under `android/`
- `lib/features/speed_test/services/upload_service.dart` — per-worker failures, earlier transfer start, prefer accepted bytes
- `lib/features/speed_test/services/download_service.dart` — per-worker failures, prefer measured bytes

## Recommendation

Rebuild the release APK/AAB only after rotating the signing key and updating GitHub secrets.  
Run the full CI workflow (`quality` + `release`) before shipping.
