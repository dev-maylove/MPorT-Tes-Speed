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
