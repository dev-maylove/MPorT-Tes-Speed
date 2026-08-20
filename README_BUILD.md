# MPorT Tes Speed - Build Notes

Server speed test: `https://speed2.haansiro.id`

Endpoints:
- Download: `/downloading`
- Upload: `/upload`

## Build in Termux / Linux

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

The Android project is included and uses Flutter's Gradle plugin loader. Java 17 is the recommended JDK for this project.

## Important

The release build currently uses the debug signing configuration so it can produce an APK for testing. For Play Store/distribution, replace it with a proper release keystore configuration.
