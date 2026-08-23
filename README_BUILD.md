# MPorT Go - Build Notes

Speed test server: configurable (default host in `ServerConfig`).

Endpoints (OpenSpeedTest-style / Ookla-style depending on selected server):
- Download: `/downloading` or `/speedtest/download`
- Upload: `/upload` or `/speedtest/upload.php`

## Android Build Matrix (Flutter 3.47.x+)

| Component | Version | Notes |
|-----------|---------|-------|
| **Gradle** | **9.1.0** | Recommended ≥ 9.1 |
| **AGP** | **9.0.1** | Requires Java 17 |
| **Kotlin** | **Built-in (AGP 9)** | `android.builtInKotlin=true` |
| **Java** | **17** | |

### `android/gradle.properties` (important)

```
android.newDsl=false
android.builtInKotlin=true
```

- `android.builtInKotlin=true` — migrated to AGP built-in Kotlin (no separate `kotlin-android` plugin in the app module).
- `android.newDsl=false` — kept for compatibility until all Flutter plugins fully support the new AGP DSL.

### App module (`android/app/build.gradle.kts`)

- Plugins: `com.android.application` + Flutter Gradle plugin only (no `kotlin-android`).
- JVM target: set via `kotlin { compilerOptions { jvmTarget = JVM_17 } }`.

## Build

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

APK output: `build/app/outputs/flutter-apk/app-release.apk`

## Signing

See **KEYSTORE.md**.

## Migration notes (Built-in Kotlin)

Followed: https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers

1. Removed `id("kotlin-android")` from the app plugins block.
2. Kept / used the `kotlin { compilerOptions { ... } }` block.
3. Set `android.builtInKotlin=true` in `gradle.properties`.
