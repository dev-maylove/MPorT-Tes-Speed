# GitHub Actions CI — MPorT Go

Workflow: `.github/workflows/build-apk.yml`

## Jobs

| Job | Trigger | Output |
|-----|---------|--------|
| **Build APK** | push/PR `main`/`master` + manual | `app-release.apk` |
| **Build AAB** | manual (`workflow_dispatch`) atau tag | `app-release.aab` |

## Flow (APK)

1. Checkout source  
2. Java 17 (Temurin) + Gradle cache  
3. Flutter stable (cached)  
4. Accept Android licenses  
5. `flutter pub get`  
6. `flutter analyze`  
7. `flutter test`  
8. Setup signing (Secrets **atau** keystore di repo)  
9. `flutter build apk --release`  
10. Fallback locate/copy APK jika path tidak standar  
11. Upload artifact **MPorT-Tes-Speed-release**

## Cara menjalankan

- **Otomatis:** push ke branch `main` / `master`
- **Manual:** GitHub → **Actions** → **Build MPorT Go APK** → **Run workflow**
- **AAB:** jalankan manual (workflow_dispatch) atau buat git tag

## Hasil

| Artifact name | File |
|---------------|------|
| `MPorT-Tes-Speed-release` | `app-release.apk` |
| `MPorT-Tes-Speed-aab` | `app-release.aab` |

Download dari tab **Actions** → pilih run → **Artifacts**.

## Signing di CI

### Opsi A — Secrets (disarankan untuk repo publik)

| Secret | Isi |
|--------|-----|
| `KEYSTORE_BASE64` | `base64 -w0 android/app/mport-release-key.jks` |
| `KEYSTORE_PASSWORD` | store password |
| `KEY_PASSWORD` | key password |
| `KEY_ALIAS` | `mport` |

### Opsi B — Keystore di repo (internal / testing)

Jika `android/key.properties` + `android/app/mport-release-key.jks` sudah ada di repo, CI memakai itu otomatis.

> **Peringatan:** Jangan commit keystore & password ke repository publik.  
> File `.gitignore` sudah meng-exclude `*.jks` dan `key.properties`.

## Matrix build

| Component | Version |
|-----------|---------|
| Gradle | **9.1.0** |
| AGP | **9.0.1** |
| Kotlin | **2.3.20** |
| Java | **17** |
| Flutter | **stable** (3.47.x) |

> AGP 9 + `android.newDsl=false` + `android.builtInKotlin=false` (opt-out breaking changes).
