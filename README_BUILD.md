# MPorT Tes Speed - Build Notes

Server speed test: `https://speed2.haansiro.id`

Endpoints:
- Download: `/downloading`
- Upload: `/upload`

## Android Build Matrix (Flutter 3.47 verified — same as MPorT ISP Portal)

| Component | Version |
|-----------|---------|
| **Gradle** | **9.3.1** |
| **AGP** | **9.1.0** |
| **Kotlin (KGP)** | **2.4.0** |
| **Java** | **17** |

File penting:
- `android/settings.gradle.kts` → AGP 9.1.0 + Kotlin 2.4.0
- `android/gradle/wrapper/gradle-wrapper.properties` → Gradle 9.3.1
- `android/gradle.properties` → `android.newDsl=false` + `android.builtInKotlin=false` (wajib untuk Flutter + AGP 9)

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

- Matrix ini sama dengan yang sukses di aplikasi MPorT ISP Portal (Laravel v2.0.1).
- Untuk Play Store, **wajib** ganti keystore & password.
- Jangan commit `key.properties` / `*.jks` ke repo publik.
