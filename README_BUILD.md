# MPorT Go - Build Notes

Server speed test: `https://speed2.haansiro.id`

Endpoints:
- Download: `/downloading`
- Upload: `/upload`

## Android Build Matrix (Flutter 3.47.x)

| Component | Version | Catatan |
|-----------|---------|---------|
| **Gradle** | **9.1.0** | Min Flutter 3.47 ≈ 8.14; recommended ≥ 9.1 |
| **AGP** | **9.0.1** | + `android.newDsl=false` |
| **Kotlin** | **2.2.20** | Min Flutter 3.47 |
| **Java** | **17** | |

### `android/gradle.properties` (penting)

```
android.newDsl=false
android.builtInKotlin=false
```

Tanpa dua flag ini, AGP 9 memaksa new DSL / built-in Kotlin dan Flutter Gradle plugin bisa gagal.

## Build

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

APK: `build/app/outputs/flutter-apk/app-release.apk`

## Signing

Lihat **KEYSTORE.md**.
