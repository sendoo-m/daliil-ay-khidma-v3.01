# Store Assets Audit — Release Candidate

This checklist gates the first production submission for both Daliil Ay Khidma mobile apps.

## Build artifacts

- [x] User Android release AAB is buildable in CI.
- [x] Merchant Android release AAB is buildable in CI.
- [x] User iOS release app is buildable without code signing.
- [x] Merchant iOS release app is buildable without code signing.
- [x] Manual RC workflow publishes short-lived Android AAB artifacts and SHA-256 checksums.
- [x] Manual RC workflow publishes unsigned iOS diagnostic artifacts.
- [ ] Production Android AABs are signed with the real Play upload keys.
- [ ] Production iOS archives/IPAs are signed with the correct Apple Team/App IDs/profiles.

> CI-generated Android RC artifacts use an ephemeral key and are for installation/build validation only. They are **not** the final binaries to upload to Google Play.

## Brand assets

### User app
- [ ] Final 1024×1024 master icon reviewed (no phone frame, text too close to edges, transparency or unintended padding).
- [ ] Android adaptive icon foreground/background reviewed on real launchers.
- [ ] iOS AppIcon set generated from the approved master.
- [ ] Launch/splash screen matches the approved Daliil brand and renders correctly in light/dark system modes.
- [ ] Google Play 512×512 icon exported from the same approved master.
- [ ] Google Play 1024×500 feature graphic approved.

### Merchant app
- [ ] Decide whether Merchant uses the same Daliil mark with a distinct Business treatment or a dedicated approved icon.
- [ ] Final 1024×1024 master icon reviewed.
- [ ] Android adaptive icon and iOS AppIcon set generated.
- [ ] Launch/splash screen reviewed.
- [ ] Google Play 512×512 icon and 1024×500 feature graphic approved.

## Screenshots

Do not create final store screenshots until the planned UI refresh is complete. Current mockups may guide the redesign but store screenshots must represent the actual shipping app.

### User screenshot story
1. Home / discovery.
2. Search.
3. Map discovery.
4. Business details.
5. Offers.
6. Favorites / notifications.
7. Account or onboarding where useful.

### Merchant screenshot story
1. Dashboard.
2. Business profile/editor.
3. Products.
4. Offers.
5. Reviews.
6. Subscription center.
7. Settings / onboarding.

Required before submission:
- [ ] Arabic phone screenshots from final build.
- [ ] English phone screenshots from final build.
- [ ] App Store screenshots for the device sizes requested by App Store Connect.
- [ ] iPad screenshots if iPad remains supported.

## Store-console inputs still requiring owner/account confirmation

- [ ] Public legal/developer name.
- [ ] Support email and support contact details.
- [ ] Google Play category.
- [ ] Apple primary/secondary category.
- [ ] Content/age rating questionnaires.
- [ ] Google Play Data Safety answers verified against final binary.
- [ ] Apple App Privacy answers verified against final binary.
- [ ] Privacy, terms, support and account-deletion production URLs verified after deployment.

## Release sequence

1. Merge release pipeline/audit only after CI and Mobile Release Smoke pass.
2. Run **Mobile Release Candidate** manually with `release_label=rc1`.
3. Download and smoke-test the generated Android RC AABs (ephemeral signing).
4. Complete the planned Dynamic Theme + UI refresh PR series.
5. Capture final store screenshots from the shipping UI.
6. Configure real Google Play upload signing and Apple signing outside the repository/secrets in GitHub Actions as appropriate.
7. Build final production binaries.
8. Re-audit privacy declarations and account deletion against those binaries.
9. Submit first to internal/TestFlight testing, then production after acceptance testing.
