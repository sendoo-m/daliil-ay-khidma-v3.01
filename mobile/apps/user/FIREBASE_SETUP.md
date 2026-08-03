# Firebase setup

The app is connected to Firebase project `gen-lang-client-0048255023` through
`lib/firebase_options.dart` and the platform client configuration under
`firebase/`. Firebase client files are identifiers shipped inside every app;
they are validated and copied into generated projects by
`tool/configure_firebase.py`.

Never commit service-account credentials, APNs authentication keys, Android
keystores, provisioning profiles, or signing passwords.

## 1. Generate Android and iOS projects

```bash
cd mobile/dalil_app
chmod +x tool/bootstrap_native.sh
./tool/bootstrap_native.sh
```

Application identifiers:

- Android: `com.daliilaykhidma.dalil_app`
- iOS: `com.daliilaykhidma.dalilApp`

## 2. Connect FlutterFire

```bash
dart pub global activate flutterfire_cli
firebase login
flutterfire configure \
  --platforms=android,ios \
  --android-package-name=com.daliilaykhidma.dalil_app \
  --ios-bundle-id=com.daliilaykhidma.dalilApp
```

Re-run this command whenever a Firebase app identifier or project changes,
then replace the matching files under `firebase/android` and `firebase/ios`.

## 3. Platform capabilities

In Xcode enable Push Notifications and Background Modes > Remote notifications.
Upload the APNs authentication key in Firebase Console. Android requires no
additional runtime capability after FlutterFire configuration.

## 4. Backend

Set these production variables on the Django service:

```env
PUSH_NOTIFICATIONS_ENABLED=True
FIREBASE_CREDENTIALS_PATH=/run/secrets/firebase-service-account.json
```

The Firebase service-account JSON belongs in the deployment secret store, not
in this repository.
