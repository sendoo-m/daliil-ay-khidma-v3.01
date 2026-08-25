# Daliil Ay Khidma — Mobile Release Readiness

This document is the source of truth for preparing the Flutter apps for Google Play and Apple App Store submission.

## Scope

Apps in this monorepo:

- `mobile/apps/user` — public/customer app
- `mobile/apps/merchant` — business owner app
- `mobile/apps/admin` — internal admin app; not planned for public store release unless explicitly approved

## Current release status

### Customer app (`mobile/apps/user`)

Status: **platform foundations are in place; release hardening is in progress**.

Completed:

- Android and iOS platform projects exist.
- Android release no longer silently uses the debug signing key; release signing is loaded from an untracked `key.properties` file.
- Production HTTPS (`https://dalilaykhidma.com`) is the default API base URL; local development can override it with `--dart-define=API_BASE_URL=...`.
- CI guards prevent restoring debug release signing or an emulator/local API default.
- Location permission declarations and the `daliil://` custom scheme already exist.

Still pending:

1. `pubspec.yaml` is now `1.0.0+1`; final store version/build number will still be bumped after release QA.
2. Android application label/app icon/store-facing name must be finalized.
3. iOS Bundle ID and Apple Developer registration/signing must be confirmed.
4. Firebase push configuration and all final permission declarations must be verified against the shipped feature set.
5. A physical-device release test is still required.
6. `android/key.properties` (the real Google Play upload keystore) does not exist locally yet — must be generated before a real release build (release builds intentionally fail without it rather than falling back to debug signing).

### Merchant app (`mobile/apps/merchant`)

Status: **Android/iOS platform projects now exist and build validation is being added**.

Completed:

- Android and iOS platform projects were added without replacing the Merchant Dart source.
- Merchant Android has a distinct application ID/namespace: `com.daliilaykhidma.merchant`.
- Merchant Android has an independent launcher activity and release upload-signing configuration.
- Customer Android Firebase configuration was removed from Merchant Android because Merchant currently does not depend on Firebase.
- iOS permission purpose strings for location, camera, and photo library use are present.

Completed (2026-08-25 review):

- Merchant iOS Xcode project's `PRODUCT_BUNDLE_IDENTIFIER` (all 6 build-config entries) and `Info.plist` now consistently use `com.daliilaykhidma.merchant`, distinct from the customer app's `com.daliilaykhidma.dalilApp`. Previously all 6 pbxproj entries had been left pointing at the customer app's bundle ID.

Still pending:

1. Final app icons / launch assets need product-approved artwork.
2. Push/Firebase must only be added if the Merchant app actually ships push notifications on mobile.
3. Store versioning and physical-device QA remain pending.
4. `android/key.properties` (the real Google Play upload keystore) does not exist locally yet — must be generated before a real release build.
5. Register the Merchant App ID (`com.daliilaykhidma.merchant`) in Apple Developer if not already done, and configure Xcode signing/capabilities against it.

## Automated release build smoke

`.github/workflows/mobile-release-smoke.yml` validates both public apps on release-shaped builds:

- Android: `flutter build appbundle --release` for User and Merchant using an ephemeral CI-only upload keystore.
- iOS: `flutter build ios --release --no-codesign` for User and Merchant on macOS.
- Both builds receive the production HTTPS API URL explicitly.

These builds verify project/build-system health only. The CI keystore is intentionally disposable and is never a production signing credential.

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
- [x] Customer Android release cannot silently use the debug signing key.
- [x] Customer app release configuration no longer defaults to localhost/emulator API.
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

- [x] Replace debug release signing with upload signing loaded from an untracked `key.properties` file.
- [x] Add CI release AAB smoke build against production HTTPS.
- [ ] Generate the real Google Play upload key locally / in protected release infrastructure.
- [ ] Install/test a release build on a physical Android device.
- [ ] Confirm target SDK meets current Play requirements at submission time.

### Customer iOS

- [x] Add CI no-codesign iOS release smoke build.
- [ ] Confirm final Bundle ID and Apple Developer App ID.
- [ ] Configure Signing & Capabilities in Xcode.
- [ ] Verify push notifications / associated domains if used.
- [ ] Archive a signed Release build with production API URL.
- [ ] Test via TestFlight before App Store review.

### Merchant Android

- [x] Generate Android runner.
- [x] Assign a distinct Android application ID.
- [x] Configure safe release upload-signing plumbing.
- [x] Add CI release AAB smoke build.
- [ ] Generate the real Google Play upload key and run physical-device QA.

### Merchant iOS

- [x] Generate iOS runner.
- [x] Add CI no-codesign iOS release smoke build.
- [x] Replace inherited customer Bundle ID references with the final Merchant Bundle ID.
- [ ] Register the Merchant App ID in Apple Developer and configure signing/capabilities.
- [ ] Archive and test through TestFlight.

## Branch cleanup

Many historical `agent/*` and `hotfix/*` branches remain after their PRs were merged. Do **not** delete them blindly. Before cleanup, compare each branch with `main`; delete only branches whose commits are fully contained in `main` or are intentionally abandoned.

## Release sequence

1. Release audit and signing/security foundation. ✅
2. Generate Merchant Android/iOS platform projects. ✅
3. Release build smoke validation. **In progress**
4. Final iOS identities/signing configuration.
5. Store compliance: privacy, account deletion, permissions, support URLs.
6. Release QA and regression fixes.
7. Version `1.0.0+<build>` (or approved release number).
8. Google Play Internal Testing + Apple TestFlight.
9. Fix store/internal-test findings.
10. Production submission.
