# MPorT Go - Build Notes

Speed test server: configurable (default host in `ServerConfig`).

Endpoints (OpenSpeedTest-style / Ookla-style depending on selected server):
- Download: `/downloading` or `/speedtest/download`
- Upload: `/upload` or `/speedtest/upload.php`

## Android Build Matrix (Flutter 3.x / AGP 9)

| Component | Version | Notes |
|-----------|---------|-------|
| **Gradle** | **9.1.0** | Recommended ≥ 9.1 |
| **AGP** | **9.0.1** | Requires Java 17 |
| **Kotlin** | **Built-in (AGP 9)** | `android.builtInKotlin=true` |
| **Java** | **17** | |

## APK size optimizations (applied)

| Optimization | Effect |
|--------------|--------|
| `--split-per-abi` | Separate APK per CPU (arm64 ~half of fat APK) |
| `--obfuscate` + R8 full mode | Smaller DEX, harder reverse-engineering |
| `--tree-shake-icons` | Drop unused Material icons |
| `--target-platform=android-arm,android-arm64` | No x86/x86_64 (via Flutter flags, not ndk.abiFilters) |
| `resourceConfigurations` en/id | Drop unused locale strings from deps |
| `isMinifyEnabled` + `isShrinkResources` | Dead code & unused resources removed |
| Compressed JNI (`useLegacyPackaging`) | Smaller native libs in APK |
| Logo/splash assets compressed | ~1.4 MB → ~61 KB logo |

## Quick build

```bash
# Recommended: per-ABI APKs (smallest install size)
./tool/build_release.sh split

# Single universal APK (armv7 + arm64 only)
./tool/build_release.sh universal

# Play Store bundle
./tool/build_release.sh appbundle
```

Manual equivalent:

```bash
flutter clean
flutter pub get
flutter build apk --release \
  --split-per-abi \
  --obfuscate \
  --split-debug-info=build/debug-info \
  --tree-shake-icons \
  --target-platform=android-arm,android-arm64
```

Outputs:
- Split: `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`
- Split: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- Universal: `build/app/outputs/flutter-apk/app-release.apk`

## Gradle flags (`android/gradle.properties`)

```
android.builtInKotlin=true
android.enableR8.fullMode=true
android.nonTransitiveRClass=true
org.gradle.parallel=true
org.gradle.caching=true
```

## Signing

See **KEYSTORE.md**.

## Migration notes (Built-in Kotlin)

1. Removed `id("kotlin-android")` from the app plugins block.
2. JVM target via `kotlin { compilerOptions { ... } }`.
3. `android.builtInKotlin=true` in `gradle.properties`.

## Fast analyze

```bash
flutter analyze --no-fatal-infos lib
# or
./tool/fast_analyze.sh
```


## Release outputs

The GitHub Actions release workflow builds both a signed universal APK and a signed Android App Bundle (AAB). The APK is suitable for direct installation/testing; the AAB is the artifact for Google Play Console.
