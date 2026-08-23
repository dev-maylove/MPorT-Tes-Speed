# Keystore — MPorT Go (Release only)

## Files

| File | Location |
|------|----------|
| `mport-release-key.jks` | `android/app/` (PKCS#12) |
| `key.properties` | `android/` |
| `keystore_release_base64.txt` | `android/` (single-line base64, optional for CI) |

## Credentials

```
storePassword = Optionso@1212
keyPassword   = Optionso@1212
keyAlias      = mport_key_tes
storeFile     = mport-release-key.jks
```

> Alias inside the keystore: **mport_key_tes**  
> Certificate SHA-256:  
> `73:04:EC:0E:80:FA:95:ED:CF:86:82:AC:DB:5C:25:0F:11:5D:C4:90:1B:DD:C4:BE:D0:CB:09:A6:81:A5:EA:B7`

## CI Secrets (GitHub Actions)

| Secret | Value |
|--------|--------|
| `KEYSTORE_BASE64` | contents of `android/keystore_release_base64.txt` |
| `KEYSTORE_PASSWORD` | `Optionso@1212` |
| `KEY_PASSWORD` | `Optionso@1212` |
| `KEY_ALIAS` | `mport_key_tes` |

**Note:** The CI workflow currently expects a different fingerprint  
(`B8:2C:BB:24:...`). If you switch CI to this release keystore, update  
`EXPECTED_SHA256` in `.github/workflows/build-apk.yml` to the SHA above,  
or keep using the secret-based `mport-release-new.jks` for production.

## Local release build

```bash
flutter build apk --release
```

Gradle resolves `storeFile` relative to the app module (`android/app/`) first,  
then `android/`. If the keystore is missing, release falls back to debug signing.
