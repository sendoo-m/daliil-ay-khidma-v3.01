# Daliil Ay Khidma — Mobile Release Readiness

This document is the source of truth for preparing the Flutter apps for Google Play and Apple App Store submission.

## Scope

Apps in this monorepo:

- `mobile/apps/user` — public/customer app
- `mobile/apps/merchant` — business owner app
- `mobile/apps/admin` — internal admin app; not planned for public store release unless explicitly approved

## Current release status

### Customer app (`mobile/apps/user`)

Status: **platform projects exist, but release build is NOT store-ready yet**.

Confirmed blockers:

1. `android/app/build.gradle.kts` signs the `release` build with the debug signing config. A Play Store release must use a private upload/release key and the key must never be committed.
2. `lib/core/config/environment.dart` defaults `API_BASE_URL` to `http://10.0.2.2:8000`. Store builds must be compiled with the production HTTPS API URL via `--dart-define=API_BASE_URL=...`; release automation must fail if this value is missing or local.
3. `pubspec.yaml` is still `0.1.0+1`. Final store candidate version will be set only after release QA is green.
4. Android application label is still the technical value `dalil_app`; final Arabic/English store-facing app name must be verified.
5. iOS `Info.plist` contains location usage text, but all permissions used by the final app (notifications, photos/camera if applicable) must be verified against actual code and plugins.
6. Bundle/Application identifiers must be confirmed as final and registered in Google Play Console / Apple Developer before signing configuration is locked.

Already present:

- Android project
- iOS project
- Firebase setup documentation/config area
- Location permission declarations
- Custom URL scheme `daliil://`
- CI analyze/test coverage

### Merchant app (`mobile/apps/merchant`)

Status: **NOT buildable for Android/iOS from `main` yet**.

Confirmed blocker:

- The app currently contains `lib`, `web`, and `pubspec.yaml`, but no `android/` or `ios/` platform projects. These must be generated from the installed Flutter SDK and then configured with final identifiers, signing, permissions, icons, Firebase/push setup, and deep links before store builds can exist.

Also pending:

- Final package / bundle identifiers
- Release signing
- Firebase configuration where required
- Platform permission descriptions
- App icons / launch assets verification
- Store versioning

## Store compliance gates

The following must be completed before production submission:

- [ ] Privacy Policy is publicly reachable via HTTPS.
- [ ] Terms / support URL is publicly reachable via HTTPS.
- [ ] Account deletion is available to signed-in users when account creation is supported, with backend behavior verified.
- [ ] Google Play Data Safety answers match actual collection/use.
- [ ] Apple App Privacy answers match actual collection/use.
- [ ] Location permission is requested only when needed and has a clear purpose string.
- [ ] Notification permission/push behavior is verified on real Android and iOS devices.
- [ ] Photo/camera/file permissions are declared only if actually required.
- [ ] No debug/test API endpoints or localhost/emulator endpoints exist in release builds.
- [ ] No secrets, signing keys, `.p12`, `.jks`, provisioning profiles, service-account credentials, or private API keys are committed.
- [ ] Production backend HTTPS and certificate chain are valid.
- [ ] Account registration, login, password reset/OTP, logout, and token refresh work in release mode.
- [ ] Arabic and English, including RTL/LTR, are tested end-to-end.
- [ ] Subscription onboarding and merchant onboarding are tested end-to-end.
- [ ] Map/location behavior is tested with permission allowed, denied, and permanently denied.
- [ ] Image/file upload limits and error states are tested on real devices.
- [ ] Deep links are tested from cold start and warm app state.

## Build gates

### Customer Android

- [ ] Replace debug signing with release/upload signing loaded from untracked `key.properties` / environment.
- [ ] Build `flutter build appbundle --release --dart-define=API_BASE_URL=https://<production-host>`.
- [ ] Install/test a release APK/AAB-derived build on a physical Android device.
- [ ] Confirm target SDK meets current Play requirements at submission time.

### Customer iOS

- [ ] Confirm final Bundle ID and Apple Developer App ID.
- [ ] Configure Signing & Capabilities in Xcode.
- [ ] Verify push notifications / associated domains if used.
- [ ] Archive a Release build with production API URL.
- [ ] Test via TestFlight before App Store review.

### Merchant Android/iOS

- [ ] Generate Flutter Android and iOS runners without overwriting app source.
- [ ] Assign identifiers distinct from the customer app.
- [ ] Configure signing and permissions.
- [ ] Configure Firebase/push/deep-link integration as required.
- [ ] Produce internal Android and TestFlight builds.

## Branch cleanup

Many historical `agent/*` and `hotfix/*` branches remain after their PRs were merged. Do **not** delete them blindly. Before cleanup, compare each branch with `main`; delete only branches whose commits are fully contained in `main` or are intentionally abandoned.

## Release sequence

1. Release audit and security/signing foundation.
2. Generate Merchant Android/iOS platform projects.
3. Production environment/build configuration.
4. Store compliance: privacy, deletion, permissions, support URLs.
5. Release QA and regression fixes.
6. Version `1.0.0+<build>` (or approved release number).
7. Google Play Internal Testing + Apple TestFlight.
8. Fix store/internal-test findings.
9. Production submission.
