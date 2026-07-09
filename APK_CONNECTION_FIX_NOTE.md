# APK connection fix

This build fixes release APK network failures by adding Android release permissions and allowing HTTP cleartext traffic.

Changed files:

- `android/app/src/main/AndroidManifest.xml`
  - Added `android.permission.INTERNET`
  - Added `android.permission.ACCESS_NETWORK_STATE`
  - Added `android:usesCleartextTraffic="true"`
  - Added `android:networkSecurityConfig="@xml/network_security_config"`

- `android/app/src/main/res/xml/network_security_config.xml`
  - Allows HTTP access for `192.1.0.28`, `3.36.14.110`, `10.0.2.2`, and localhost.

Build command:

```powershell
flutter clean
flutter pub get
flutter build apk --release `
  --dart-define=AUTH_API_BASE_URL=http://3.36.14.110:8000 `
  --dart-define=API_BASE_URL=http://192.1.0.28:8001
```

The APK will be created at:

`build/app/outputs/flutter-apk/app-release.apk`

Before testing on a phone, start the local server:

```powershell
python -m uvicorn main:app --host 0.0.0.0 --port 8001 --reload
```

Then check on the phone browser:

`http://192.1.0.28:8001/docs`
