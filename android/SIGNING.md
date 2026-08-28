# Android release signing

Release signing material is intentionally not stored in this repository.

GitHub Actions reconstructs `android/app/mport-release.jks` and `android/key.properties` from these repository/environment secrets:

- `KEYSTORE_BASE64`
- `KEYSTORE_PASSWORD`
- `KEY_ALIAS`
- `KEY_PASSWORD`

The release workflow verifies that:

1. the keystore exists and contains a `PrivateKeyEntry` for `KEY_ALIAS`;
2. the APK signature is cryptographically valid;
3. the APK certificate SHA-256 matches the CI keystore certificate;
4. the AAB signature is cryptographically valid;
5. the AAB certificate SHA-256 matches the same CI keystore certificate.

Temporary signing material is deleted in an `if: always()` cleanup step.
