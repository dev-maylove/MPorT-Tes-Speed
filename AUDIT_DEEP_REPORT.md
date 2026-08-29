# MPorT v23 Deep Audit

## Findings fixed
1. Upload payload cache resurrection: an in-flight isolate generation could repopulate `_cachedPayload` after `releaseCache()`. Fixed with payload-generation invalidation.
2. Reused service cancellation race: a second operation could reset `_cancelled` while an older operation was still in flight. Upload, download and ping now use operation IDs.
3. Cancellation semantics: upload/download now return a neutral cancelled result instead of throwing a misleading server failure after an intentional cancel.
4. Measurement-window underflow: short/custom test durations below the grace period could produce a negative measured duration/bytes. Clamped safely.
5. Server selection race: a late `selectNearest()` result could overwrite a user's manual server selection. Manual selection now invalidates the in-flight selection generation.
6. Unused Android permissions: removed CHANGE_NETWORK_STATE and CHANGE_WIFI_STATE from the manifest because the app only observes network state and does not programmatically change it.

## Deliberately not changed
- v23 signing workflow, because v23 is the known-good build baseline.
- Server catalog and HTTP cleartext requirement, because the catalog intentionally contains HTTP speed-test endpoints; changing transport would alter compatibility.
- Product version/build metadata, because v23's built artifact is already established and version bumps should be intentional releases.

## Validation available in this environment
- ZIP extracted successfully.
- Bash/Gradle wrapper files present.
- Source-level changes inspected.
- Flutter SDK is not installed in this runtime, so `flutter analyze` and `flutter test` cannot be executed here.
