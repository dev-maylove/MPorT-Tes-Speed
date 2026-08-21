# MPorT Tes Speed - Build Notes

Server speed test: `https://speed2.haansiro.id`

Endpoints:
- Download: `/downloading`
- Upload: `/upload`

## Android Build Matrix (Flutter 3.47 stable)

| Component | Version |
|-----------|---------|
| **Gradle** | **8.14.3** (min Flutter 3.47 = 8.14) |
| **AGP** | **8.11.1** |
| **Kotlin (KGP)** | **2.1.0** |
| **Java** | **17** |

> AGP 9.x belum direkomendasikan Flutter untuk production.  
> Gradle harus ≥ 8.14 karena validasi Flutter Gradle plugin.

File penting:
- `android/settings.gradle.kts` → AGP 8.11.1 + Kotlin 2.1.0
- `android/gradle/wrapper/gradle-wrapper.properties` → Gradle 8.14.3
- `android/build.gradle.kts` → buildDir `../../build`

## Build

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

APK output: `build/app/outputs/flutter-apk/app-release.apk`

## Signing (Release Keystore)

Lihat **KEYSTORE.md**.

- Keystore: `android/app/mport-release-key.jks`
- Config: `android/key.properties`

## Catatan

- Untuk Play Store, **wajib** ganti keystore & password.
- Jangan commit `key.properties` / `*.jks` ke repo publik.
