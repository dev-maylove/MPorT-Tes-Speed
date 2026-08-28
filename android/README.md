# Android platform

Run from project root:

```bash
flutter create . --project-name mport_test_speed --org id.haansiro
flutter pub get
flutter run
```

Signing: see `KEYSTORE.md` in the project root.

## Release signing

Release signing credentials are intentionally not included in this source archive.
Configure `android/key.properties` and provide the replacement keystore through your
local/CI secret store before building a release. Never commit keystores, passwords,
or base64-encoded signing material.
