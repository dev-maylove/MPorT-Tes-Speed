# MPorT Tes Speed - Build Notes

Server speed test: `https://speed2.haansiro.id`

Endpoints:
- Download: `/downloading`
- Upload: `/upload`

## Android Build Matrix (stabil untuk Flutter 3.47)

| Component | Version |
|-----------|---------|
| **Gradle** | **8.12** |
| **AGP** | **8.9.1** |
| **Kotlin (KGP)** | **2.1.0** |
| **Java** | **17** |

> AGP 9.x belum direkomendasikan Flutter (plugin ecosystem belum siap).  
> Matrix di atas stabil untuk CI GitHub Actions + Flutter stable 3.47.

File penting:
- `android/settings.gradle.kts` → AGP 8.9.1 + Kotlin 2.1.0
- `android/gradle/wrapper/gradle-wrapper.properties` → Gradle 8.12
- `android/build.gradle.kts` → buildDir diarahkan ke `../../build` (root proyek)

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

Release build otomatis memakai keystore ini jika `key.properties` ada.

## Catatan

- Untuk Play Store, **wajib** ganti keystore & password.
- Jangan commit `key.properties` / `*.jks` ke repo publik (lihat `.gitignore`).
