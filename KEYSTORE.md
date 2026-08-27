# Keystore — MPorT Go

The release keystore must **not** be stored in the repository.

## GitHub Actions

Configure these repository secrets:

- `KEYSTORE_BASE64` — Base64 contents of the release `.jks`
- `KEYSTORE_PASSWORD`
- `KEY_PASSWORD`
- `KEY_ALIAS`

The workflow reconstructs the JKS only for the duration of the release build, verifies the alias, signs the AAB, and deletes the temporary JKS and `android/key.properties` afterwards.

## Create the Base64 secret from Termux/Linux

Keep the original JKS outside the project directory, for example:

```bash
mkdir -p ~/keystore
base64 -w 0 ~/keystore/mport-release.jks
```

Copy the output into the GitHub Actions secret `KEYSTORE_BASE64`.

Do not paste the keystore password into workflow files.

## Local release build

For a local signed build, create `android/key.properties` locally and point `storeFile` at your local JKS. Never commit either file.

The Gradle configuration intentionally fails when a release keystore is missing; it will never silently produce a debug-signed release artifact.

## Google Play

The resulting `MPorT-Tes-Speed-release.aab` is the artifact to upload to Google Play Console. Keep the keystore and its passwords backed up securely; future updates must use the same signing identity unless you deliberately use Google Play App Signing key management.
