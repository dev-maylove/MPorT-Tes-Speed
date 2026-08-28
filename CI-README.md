# GitHub Actions CI — MPorT Go

Workflow: `.github/workflows/build-apk.yml`

## Pipeline

| Job | Trigger | Output |
|-----|---------|--------|
| **Analyze & Test** | push / pull request / tag / manual | CI result |
| **Build Signed Android App Bundle** | push to `main`/`master`, `v*` tag, or manual | signed `.aab` |

Pull requests run analysis and tests only. Release signing is deliberately skipped on PRs so GitHub Actions secrets are never exposed to untrusted PR code.

## GitHub Secrets

Create these repository secrets under **Settings → Secrets and variables → Actions**:

| Secret | Value |
|--------|-------|
| `KEYSTORE_BASE64` | Base64 contents of your release `.jks` |
| `KEYSTORE_PASSWORD` | Keystore password |
| `KEY_ALIAS` | Release key alias |
| `KEY_PASSWORD` | Release key password |

Example from Termux/Linux:

```bash
base64 -w 0 ~/keystore/mport-release.jks
```

Copy the resulting single-line value into `KEYSTORE_BASE64`.

**Never commit the `.jks`, `android/key.properties`, passwords, or Base64 signing material to Git.**

## Signed AAB flow

1. GitHub Actions checks out the source.
2. Flutter analyzes and tests the project.
3. The four signing secrets are validated.
4. `KEYSTORE_BASE64` is decoded temporarily to `android/app/mport-release.jks`.
5. `android/key.properties` is generated temporarily.
6. Gradle verifies the keystore alias.
7. `flutter build appbundle --release` creates the Play Store AAB.
8. `jarsigner` verifies that the resulting AAB is signed.
9. The AAB and obfuscation debug-info archive are uploaded as workflow artifacts.
10. Temporary signing files are deleted even if the build fails.

## Artifact

The Actions artifact **MPorT-Tes-Speed-Play-Release** contains:

- `MPorT-Tes-Speed-release.aab` — signed Android App Bundle for Google Play
- `MPorT-Tes-Speed-debug-info.tar.gz` — keep this for crash/symbolication support when obfuscation is enabled
- `SHA256SUMS.txt` — SHA-256 checksums

## Release signing behavior

`android/app/build.gradle.kts` intentionally fails a release build when a valid release keystore is not available. This prevents an accidental debug-signed production release.


### v18
The signing verification parser was hardened to extract SHA-256 fingerprints by label rather than colon-separated field position. This fixes the false mismatch `got CERTIFICATESHA-256DIGEST`.
