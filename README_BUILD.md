# MPorT Tes Speed - Build Notes

Server speed test: `https://speed2.haansiro.id`

Endpoints:
- Download: `/downloading`
- Upload: `/upload`

## Gradle / AGP (sudah diperbaiki)

| Komponen | Versi |
|----------|-------|
| Android Gradle Plugin (AGP) | **8.11.1** |
| Gradle | **8.13** |
| Kotlin | **2.1.20** |
| Java | 17 |

File penting:
- `android/settings.gradle.kts` → mendefinisikan AGP 8.11.1
- `android/gradle/wrapper/gradle-wrapper.properties` → Gradle 8.13
- `android/gradle.properties` → `android.newDsl=false` + `android.builtInKotlin=false`

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

Lihat file **KEYSTORE.md** untuk detail lengkap.

- Keystore: `android/app/mport-release-key.jks`
- Config: `android/key.properties`

Release build otomatis memakai keystore ini jika `key.properties` ada.

## Catatan

- Untuk Play Store, **wajib** ganti keystore & password.
- Jangan commit `key.properties` / `*.jks` ke repo publik.
