# GitHub Actions CI — MPorT Tes Speed

Workflow:
- `.github/workflows/build-apk.yml`

Build flow:
1. Checkout source
2. Java 17
3. Flutter stable
4. `flutter pub get`
5. `flutter analyze`
6. `flutter test`
7. `flutter build apk --release`
8. APK uploaded as GitHub Actions Artifact

## Cara menjalankan

Push ke branch `main` atau `master`, atau jalankan manual dari:
GitHub → Actions → Build MPorT Tes Speed APK → Run workflow

## Hasil APK

Artifact:
`MPorT-Tes-Speed-release`

File:
`app-release.apk`
