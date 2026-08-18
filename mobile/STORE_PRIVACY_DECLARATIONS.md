# Store Privacy Declarations

This document is the release source of truth for Google Play **Data Safety** and Apple **App Privacy** declarations for the Daliil Ay Khidma mobile apps.

It must be reviewed whenever authentication, analytics, maps/location, notifications, uploads, payments/subscriptions, advertising, crash reporting, or third-party SDKs change.

> Important: Store declarations must describe the production build actually shipped. This file is a release checklist, not a substitute for verifying the final AAB/IPA and enabled SDK configuration.

## Apps in scope

- User app: `mobile/apps/user`
- Merchant app: `mobile/apps/merchant`

Both apps use the same Daliil Ay Khidma backend and authenticated account system.

---

## 1. Account and contact data

### Data types

- Username / account identifier
- First and last name
- Email address
- Phone number
- Password is transmitted only for authentication / re-authentication and is not displayed back to the app
- Optional profile biography and city

### User app

Collected: **Yes**

Linked to identity: **Yes**

Purpose:

- Account creation and authentication
- Account management
- Personalization of the signed-in experience
- Support and security

Google Play categories:

- Personal info → Name
- Personal info → Email address
- Personal info → Phone number
- Personal info → User IDs

Apple categories:

- Contact Info → Name
- Contact Info → Email Address
- Contact Info → Phone Number
- Identifiers → User ID

Sharing: **Do not mark as shared unless a production third-party processor receives this data for its own purpose.** Hosting/service processors acting solely on our behalf must be reviewed against current store definitions before submission.

### Merchant app

Collected: **Yes**

Linked to identity: **Yes**

Purpose:

- Merchant authentication
- Business ownership / authorization
- Support and account security

Use the same Play / Apple categories as above.

---

## 2. Precise / approximate location

The apps contain map and location functionality. Final declarations must match the exact production permission flow and whether coordinates are uploaded to the backend.

### User app

Potentially collected: **Yes when the user enables location-based discovery.**

Linked to identity: **Potentially yes when authenticated requests contain account credentials.**

Purpose:

- App functionality
- Nearby discovery / map results

Google Play:

- Location → Approximate location
- Location → Precise location, if GPS-level coordinates are requested or transmitted

Apple:

- Location → Precise Location, when exact location is used
- Location → Coarse Location, when only approximate location is used

The store answer must reflect actual production behavior, not only declared OS permissions.

### Merchant app

Collected: **Yes when a merchant sets or updates a business location.**

Linked to identity: **Yes**

Purpose:

- App functionality
- Business listing and map placement

The merchant may provide coordinates or a location URL for the business.

---

## 3. Photos and user-provided files

### User app

Collected when used: **Yes, if profile or other user-upload features are enabled in the production build.**

Purpose:

- App functionality
- Profile / user-generated content

Google Play:

- Photos and videos → Photos

Apple:

- User Content → Photos or Videos

### Merchant app

Collected: **Yes**

Examples:

- Business logo
- Cover image
- Product images
- Images associated with business/profile editing

Linked to identity/business account: **Yes**

Purpose:

- App functionality
- Business content publishing

Google Play:

- Photos and videos → Photos

Apple:

- User Content → Photos or Videos
- User Content → Other User Content when applicable

---

## 4. Business and catalog content

Merchant-generated data includes business details, products, deals/offers, working information, contact channels, and related operational content.

Collected: **Yes**

Linked to merchant account: **Yes**

Purpose:

- App functionality
- Publishing business listings and catalog content
- Subscription entitlement enforcement

Google Play mapping normally falls under:

- App activity / Other user-generated content where applicable
- Personal info only when the submitted business field is also personal contact information

Apple mapping:

- User Content → Other User Content
- Contact Info when a merchant submits personal phone/email details

Do not classify public business listing content as anonymous merely because it is displayed publicly; it remains linked to the merchant account in the backend.

---

## 5. Reviews, favorites, notifications, and other app activity

### User app

Collected / stored when used:

- Favorites
- Reviews and ratings
- Notification state
- Search/discovery activity where persisted by the backend or local storage

Linked to identity:

- Favorites/reviews: **Yes when authenticated**
- Local-only search history: verify whether it leaves the device in the production build

Purpose:

- App functionality
- Personalization
- Customer support / moderation where applicable

Google Play possible categories:

- App activity → App interactions
- User-generated content for reviews

Apple possible categories:

- Usage Data → Product Interaction
- User Content → Other User Content

Only declare data as collected if it is transmitted off-device. Local-only data that never leaves the device should not be declared as collected merely because the app stores it locally.

---

## 6. Device / push notification identifiers

The project registers devices for push notifications.

Collected: **Yes when push notifications are enabled / device registration occurs.**

Linked to identity: **Yes for authenticated device registration.**

Purpose:

- App functionality
- Notifications
- Security/session management where applicable

Google Play:

- Device or other IDs → Device or other IDs

Apple:

- Identifiers → Device ID

If Firebase Cloud Messaging or another push processor is enabled in the final build, verify the vendor's current privacy/data-processing documentation before store submission.

---

## 7. Authentication and security data

Data includes access/refresh tokens, session state, password-reset tokens, and account-deletion re-authentication requests.

Collected/processed: **Yes**

Linked to identity: **Yes**

Purpose:

- Account management
- Fraud prevention / security
- Authentication

Do not describe passwords or tokens as analytics data. Tokens are security credentials and must never be added to logs or store metadata.

The mobile account-deletion workflow sends the current password for re-authentication and may send the refresh token so the backend can blacklist it. Local tokens are cleared after server acceptance.

---

## 8. Subscription and payment-related data

The platform stores subscription plan selection, billing period, subscription status, payment review state, and merchant onboarding/payment workflow data.

Collected: **Yes when a user selects or manages a paid plan.**

Linked to identity: **Yes**

Purpose:

- App functionality
- Subscription management
- Administrative review

Google Play / Apple financial-data declarations depend on the final production payment implementation.

### Critical release rule

If the shipped apps begin collecting card details, bank/payment credentials, transaction identifiers from a payment provider, or other financial information directly or through an SDK, this section **must be re-audited before submission**. Do not claim financial data is not collected solely because the current workflow is manual/admin-reviewed.

---

## 9. Diagnostics, analytics, advertising, and tracking

At the time this document is authored, no store declaration should be inferred merely from Flutter itself.

Before submission inspect the final dependency graph and runtime configuration for:

- Firebase Analytics
- Crashlytics
- Sentry
- Google Analytics
- Meta/Facebook SDK
- Advertising SDKs
- Attribution SDKs
- Any SDK using IDFA/AAID or cross-app identifiers

If any are enabled, update this document and both store forms.

### Tracking

Do **not** answer that the app tracks users across apps/websites unless the production build actually performs tracking under Apple's definition.

If any advertising/attribution SDK introduces tracking, App Tracking Transparency requirements and the Apple privacy answers must be re-evaluated.

---

# Google Play Data Safety working answers

Use these as a starting checklist and verify against the final production build.

| Data category | User app | Merchant app | Linked to user | Primary purpose |
| --- | --- | --- | --- | --- |
| Name | Yes | Yes | Yes | Account management |
| Email address | Yes | Yes | Yes | Account management / support |
| Phone number | Yes | Yes | Yes | Account management / business contact |
| User ID | Yes | Yes | Yes | Authentication |
| Approx./precise location | When location is used | When business location is set | Usually yes | App functionality |
| Photos | When uploaded | Yes | Yes | App functionality / content |
| User-generated content | Reviews/profile content | Business/product/deal content | Yes | App functionality |
| App interactions | Favorites/reviews and server-side activity where retained | Merchant management actions where retained | Usually yes | App functionality |
| Device or other IDs | Push registration | Push registration | Yes when authenticated | Notifications |
| Financial info | Re-audit when production payment integration is finalized | Re-audit when production payment integration is finalized | TBD | Subscription/payment |

### Google Play security questions

Before submission verify:

- Production API uses HTTPS only.
- Authentication credentials are not logged.
- Account deletion is available inside the app and at the public account-deletion URL.
- The public Privacy Policy URL is reachable without authentication.
- Data deletion / retention language matches actual backend handling.

---

# Apple App Privacy working labels

Expected categories to review in App Store Connect:

- Contact Info
  - Name
  - Email Address
  - Phone Number
- Location
  - Precise Location and/or Coarse Location depending on final runtime behavior
- User Content
  - Photos or Videos
  - Other User Content
- Identifiers
  - User ID
  - Device ID for push registration where applicable
- Usage Data
  - Product Interaction only where interaction data is transmitted and retained off-device
- Purchases / Financial Info
  - Re-audit once the production payment mechanism is finalized

For every Apple category, separately answer:

1. Is it collected?
2. Is it linked to the user's identity?
3. What purposes apply?
4. Is it used for tracking?

Do not copy a single answer across all categories without checking actual behavior.

---

# OS permissions / capabilities verification

Before Release Candidate, verify the final manifests and plist files for both apps.

## Android

Review:

- Internet
- Location permissions
- Camera only if camera capture is enabled
- Photo/media access according to the Android API level and picker implementation
- Notification permission on Android versions that require runtime notification consent

Remove permissions that are not used by the production build.

## iOS

Review all `Info.plist` usage descriptions, including when applicable:

- Location When In Use
- Camera
- Photo Library / Add Photos

Every declared usage string must describe the feature users actually see.

Also verify capabilities used for push notifications and any associated-domain/deep-link configuration once enabled.

---

# Public compliance URLs

Production must expose these via HTTPS without sign-in:

- `/privacy/`
- `/terms/`
- `/support/`
- `/account-deletion/`

Account deletion is also available from the signed-in User profile and Merchant settings flow. The backend disables the account and owned business listings immediately after an authenticated deletion request while preserving data needed for controlled final processing rather than performing an unsafe immediate CASCADE deletion.

---

# Final pre-submission verification

Before entering the answers in Google Play Console or App Store Connect:

- [ ] Build the exact release candidate AAB/IPA.
- [ ] Re-check `pubspec.lock` and native SDK/plugin dependencies.
- [ ] Confirm whether analytics/crash/advertising SDKs are enabled.
- [ ] Confirm production push provider and device-token behavior.
- [ ] Test location permission denial and acceptance paths.
- [ ] Test photo/camera permission denial and acceptance paths.
- [ ] Test account deletion end-to-end in User app.
- [ ] Test account deletion end-to-end in Merchant app.
- [ ] Confirm deleted/disabled users cannot authenticate again.
- [ ] Confirm merchant businesses are hidden immediately after a deletion request.
- [ ] Confirm Privacy Policy and account-deletion URLs are public over HTTPS.
- [ ] Re-audit payment/financial-data answers after the production payment method is finalized.
- [ ] Enter store declarations from this verified release state, not from development assumptions.
