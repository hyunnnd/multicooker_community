# Graphene MultiCooker release APK build script
# Run this in the project root with PowerShell.

flutter clean
flutter pub get
flutter build apk --release `
  --dart-define=AUTH_API_BASE_URL=http://3.36.14.110:8000 `
  --dart-define=API_BASE_URL=http://192.1.0.28:8001

Write-Host "APK path: build\app\outputs\flutter-apk\app-release.apk"
