# MPorT Go

**Accurate internet speed testing for Android** — ping, jitter, download, and upload with a live neon gauge, local history, and multi-server selection.

![Flutter](https://img.shields.io/badge/Flutter-stable-02569B?logo=flutter)
![Platform](https://img.shields.io/badge/platform-Android-3DDC84?logo=android)
![License](https://img.shields.io/badge/license-MIT-blue)

---

## Features

| Area | Details |
|------|---------|
| **Latency** | Ping, average, jitter, packet loss |
| **Throughput** | Multi-thread download & upload with progress gauge |
| **Network context** | Wi-Fi / mobile detection, ISP & device labels |
| **History** | Local results stored on device |
| **Servers** | Configurable test endpoints with nearest / fallback selection |
| **UI** | Dark neon theme, light mode support, live speed dial |

---

## Requirements

- Flutter **stable** (see `pubspec.yaml` SDK constraint)
- Android SDK / JDK **17** for release builds
- A device or emulator with network access

```bash
flutter --version
flutter doctor
```

---

## Getting started

```bash
git clone <repository-url>
cd mport
flutter pub get
flutter run
```

### Useful commands

```bash
flutter analyze --no-fatal-infos
flutter test
flutter build apk --release
flutter build appbundle --release
```

---

## Project structure

```
lib/
  app/                 # Theme, router, root widget
  core/                # Colors, storage, network helpers, permissions
  features/
    speed_test/        # Engine, screens, gauge, history
    splash/            # Launch video / branding
    server/            # Server list & selection
android/               # Gradle, signing, launcher assets
assets/                # Images, splash video
test/                  # Unit & regression tests
.github/workflows/     # CI: analyze, test, signed APK/AAB
```

---

## Speed test engine

A single run is isolated by a monotonic run id so cancelled or network-changed sessions cannot publish stale results.

1. **Ping phase** — latency, jitter, loss
2. **Download phase** — parallel streams, live Mbps
3. **Upload phase** — parallel streams, live Mbps
4. **Complete** — result panel + optional history save

Connectivity changes during a run abort the test. Server failures can fall back to another configured endpoint.

Endpoint URLs and infrastructure details are **not** documented publicly; they live in app configuration only.

---

## Android release

Signing material must never be committed.

1. Configure secrets / `key.properties` as described in [`android/SIGNING.md`](android/SIGNING.md)
2. Build:

```bash
flutter clean
flutter pub get
flutter build apk --release
flutter build appbundle --release
```

Outputs:

- APK: `build/app/outputs/flutter-apk/app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`

CI builds signed artifacts on push to `main`/`master` and on version tags. Pull requests run **analyze + test only** (no signing).

---

## Continuous integration

| Job | Trigger | Actions |
|-----|---------|---------|
| **Analyze & Test** | PR + push | `pub get`, `flutter analyze`, `flutter test` |
| **Signed APK + AAB** | Push / tag (not PR) | Release build, apksigner verify, upload artifacts |

See [`.github/workflows/build-apk.yml`](.github/workflows/build-apk.yml).

---

## Security

Please report vulnerabilities privately. See **[SECURITY.md](SECURITY.md)** for supported versions, scope, and reporting process.

Highlights in current builds:

- Network Security Config — cleartext HTTP only for known speed-test hosts
- Speed-test history encrypted with `flutter_secure_storage`
- WebView navigation restricted by host allow-list
- Feature-scoped runtime permissions
- Release: R8 minify, obfuscate, tree-shake icons

Do not commit keystores, API keys, tokens, or internal server credentials.

---

## License

MIT — see [LICENSE](LICENSE).

---

## Disclaimer

Measured speeds depend on the device, radio conditions, ISP path, and selected test server. Results are indicative and may differ from other speed-test products.
