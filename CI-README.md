# GitHub Actions CI — MPorT Tes Speed

Workflow: `.github/workflows/build-apk.yml`

## Jobs

| Job | Trigger | Output |
|-----|---------|--------|
| **Build APK** | push/PR `main`/`master` + manual | `app-release.apk` |
| **Build AAB** | manual (`workflow_dispatch`) atau tag | `app-release.aab` |

## Flow (APK)

1. Checkout source  
2. Java 17 (Temurin)  
3. Flutter stable (cached)  
4. `flutter pub get`  
5. `flutter analyze`  
6. `flutter test`  
7. Setup signing (Secrets **atau** keystore di repo)  
8. `flutter build apk --release`  
9. Upload artifact **MPorT-Tes-Speed-release**

## Cara menjalankan

- **Otomatis:** push ke branch `main` / `master`
- **Manual:** GitHub → **Actions** → **Build MPorT Tes Speed APK** → **Run workflow**
- **AAB:** jalankan manual (workflow_dispatch) atau buat git tag

## Hasil

| Artifact name | File |
|---------------|------|
| `MPorT-Tes-Speed-release` | `app-release.apk` |
| `MPorT-Tes-Speed-aab` | `app-release.aab` |

Download dari tab **Actions** → pilih run → **Artifacts**.

## Signing di CI

### Opsi A — Secrets (disarankan untuk repo publik)

Buat GitHub Secrets:

| Secret | Isi |
|--------|-----|
| `KEYSTORE_BASE64` | `base64 -w0 android/app/mport-release-key.jks` |
| `KEYSTORE_PASSWORD` | store password |
| `KEY_PASSWORD` | key password |
| `KEY_ALIAS` | `mport` |

### Opsi B — Keystore di repo (internal / testing)

Jika `android/key.properties` + `android/app/mport-release-key.jks` sudah ada di repo, CI memakai itu otomatis.

> **Peringatan:** Jangan commit keystore & password ke repository publik.

## Matrix build (sesuai README_BUILD)

- Gradle **9.3.1**
- AGP **9.1.0**
- Kotlin **2.4.0**
- Java **17**
- Flutter **stable**
