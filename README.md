# MPorT Go

Flutter application for accurate internet speed testing using application-configured test servers.

## Features

- Ping & Jitter
- Download speed with parallel threads
- Upload speed with parallel threads
- Speed gauge with dark theme
- Local test history via SharedPreferences
- Bottom navigation:
  - Speed Test
  - History
  - (Maps, Server, Settings, About, etc.)

## Speed Test Engine

The app performs:

- Latency testing
- Jitter measurement
- Download testing
- Upload testing
- Parallel connections for better accuracy
- Overhead adjustment on results

Endpoint details, server addresses, and infrastructure configuration are managed inside the app and are not published in project documentation.

## Getting started

```bash
flutter pub get
flutter run
```

## Release build (Android)

See **README_BUILD.md** and **KEYSTORE.md**.

```bash
flutter clean
flutter pub get
flutter build apk --release
```

APK: `build/app/outputs/flutter-apk/app-release.apk`

## Built-in Kotlin (AGP 9+)

This project has been migrated to AGP built-in Kotlin:

- `android.builtInKotlin=true` in `android/gradle.properties`
- `kotlin-android` plugin removed from `android/app/build.gradle.kts`
- Kotlin JVM target set via `kotlin { compilerOptions { ... } }`

Guide: https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers

## Security note

Do not commit internal server addresses, credentials, API keys, tokens, or secrets into the public README or repository.
