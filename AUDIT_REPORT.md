# MPorT-Tes-Speed Deep Audit

## Fixed
- Removed committed Android keystores, `key.properties`, and base64 signing material.
- Removed release signing credentials/fingerprints from project documentation.
- Release builds now fail instead of silently falling back to debug signing.
- Restored valid Gradle wrapper configuration and added a self-bootstrapping `android/gradlew`, because the archive contained no usable Gradle wrapper executable/jar.
- Fixed download/upload cache-busting URL construction when endpoints already contain query parameters.
- Reworked final throughput scoring to use the complete measured post-warm-up transfer window instead of the fastest 10%, avoiding systematic over-reporting.
- Removed the arbitrary 0.82 ping correction; displayed latency now reflects measured HTTP RTT.
- Fixed jitter calculation to use chronological samples instead of sorted samples.
- Server probing no longer treats HTTP 4xx responses as successful latency probes.
- Added cancellation support to the ping phase so cancelling a test does not leave a long-running ping sequence.
- Ensured upload payload cache is released on cancellation paths.
- Updated stale history documentation.

## Remaining environmental validation
This environment does not have the Flutter SDK installed, so `flutter analyze` and `flutter test` could not be executed here. The project was statically audited and the CI workflow remains configured to run both checks.

## Security action required
The previous archive contained a release keystore and its password. Those credentials must be considered compromised. Rotate/revoke the old release signing material where possible and configure the replacement release keystore only through GitHub Actions secrets.

## CI incident fixed — 2026-08-27

The signed build itself completed successfully: both the release APK and AAB were produced and the release keystore was verified. The workflow failed afterward because it expected the JDK `jarsigner` human-readable output to contain the exact string `jar verified`. That text is not a stable machine-readable contract across JDK versions/builds.

Fixes:
- APK signature verification now uses Android SDK `apksigner verify --verbose`.
- AAB signature verification now relies on `jarsigner -verify` exit status instead of grepping its output.
- Gradle VFS file watching is disabled in CI to avoid the non-fatal `Already watching path` warning seen between the APK and AAB builds.
- APK + AAB output remains enabled.

## v5 DWARF warning fix

Release APK and AAB builds now pass native ELF stripping via the Android NDK `llvm-strip` together with `--obfuscate` and `--split-debug-info`. This instructs Flutter's AOT `gen_snapshot` to strip DWARF from the generated ELF while retaining split debug information for symbolization. The flag is applied to both APK and App Bundle builds.

## GitHub Actions Node.js 24 artifact update
- Updated `actions/upload-artifact` from `v4` to `v7`.
- This removes the Node.js 20 deprecation warning from the artifact upload step by using the current Node.js 24-compatible major release.
- APK and AAB artifact behavior is unchanged.


## v8 CI fix
- Fixed release NDK preparation: `sdkmanager` is now resolved explicitly from Android command-line tools instead of assuming it is on PATH.
- Validates `ANDROID_HOME`/`ANDROID_SDK_ROOT` before use and adds the resolved sdkmanager directory to `GITHUB_PATH`.
- Keeps APK + AAB signed build and NDK/llvm-strip verification unchanged.

## v9 speed-test responsiveness + gauge/result consistency — 2026-08-28

### Fixed
- Live download/upload gauge values now use the same measured-window byte/time formula as the final result. This removes the previous mismatch where the needle used EMA instantaneous samples while the final result used total measured bytes.
- Upload result counting now accepts only successful 2xx responses and does not count requests that complete after the test deadline.
- Removed the final needle reset after completion so the final gauge state is not artificially different from the reported value during the hand-off to the result panel.
- Removed the animated pulse controller from the gauge's rebuild dependency. The gauge no longer rebuilds at 60 fps just because decorative glow is pulsing, reducing rendering pressure during test start and measurement.
- Deferred non-critical server probing, ISP/device metadata and permission work until after startup. Pressing GO cancels the deferred startup probe so it cannot compete with ping/download/upload connections.
- Deferred upload payload pre-warming slightly after the first frame so Android startup/render work gets priority.
- Added unit coverage for the shared throughput formula and invalid-input handling.

### Validation limitation
- Flutter/Dart SDK is not installed in this execution environment, so `flutter analyze` and `flutter test` could not be executed here. Static source inspection, targeted consistency checks, and archive inspection were performed instead.

### Signing security
- Removed release/test keystores, `key.properties`, and base64 signing material from the redistributed source archive. The release Gradle configuration intentionally requires replacement signing credentials supplied locally or through CI secrets.


## v18 CI signing verification fix — 2026-08-28
- Fixed APK certificate fingerprint extraction. `apksigner` prints the signer prefix before `certificate SHA-256 digest`, so the previous `awk -F': '` parser captured the label itself and produced `CERTIFICATESHA-256DIGEST...` instead of the digest.
- Replaced the fragile field-position parser with label-based extraction for both APK (`apksigner`) and AAB (`jarsigner`) certificate fingerprints.
- APK/AAB fingerprints are normalized to uppercase hexadecimal before comparison.
