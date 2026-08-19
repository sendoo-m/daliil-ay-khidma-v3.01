# Daliil Ay Khidma — Store Release Metadata v1

This file is the source of truth for the first Google Play / App Store release. It must stay aligned with the actual Android/iOS projects and the final store-console records.

## Release version

- User app: `1.0.0+1`
- Merchant app: `1.0.0+1`

## App identities

### User app

- Arabic display name: **دليل أي خدمة**
- English store name: **Daliil Ay Khidma**
- Android application ID: `com.daliilaykhidma.dalil_app`
- iOS bundle ID: `com.daliilaykhidma.dalilApp`
- Purpose: discover local businesses, products, services and offers; search and map discovery; favorites, reviews, notifications and subscription onboarding.

### Merchant app

- Arabic display name: **دليل أي خدمة - الأعمال**
- English store name: **Daliil Ay Khidma Business**
- Android application ID: `com.daliilaykhidma.merchant`
- iOS bundle ID: `com.daliilaykhidma.merchant`
- Purpose: let business owners manage businesses, products, offers, reviews, subscriptions, settings and onboarding.

## Google Play listing draft

### User app — short description (AR)

اكتشف المحلات والخدمات والمنتجات والعروض القريبة منك بسهولة.

### User app — short description (EN)

Discover nearby businesses, services, products and offers with ease.

### User app — full description (AR)

دليل أي خدمة يساعدك على الوصول إلى المحلات والخدمات والمنتجات والعروض في مكان واحد. ابحث بالاسم أو التصنيف، استكشف النتائج على الخريطة، احفظ الأماكن المفضلة، تابع الإشعارات، وشارك تجربتك بالتقييمات. تم تصميم التطبيق ليجعل اكتشاف الأنشطة والخدمات المحلية أسرع وأسهل.

### User app — full description (EN)

Daliil Ay Khidma helps you discover local businesses, services, products and offers in one place. Search by name or category, explore results on the map, save favorites, receive notifications and share your experience through reviews. The app is designed to make local discovery simple and fast.

### Merchant app — short description (AR)

أدر نشاطك ومنتجاتك وعروضك واشتراكك من مكان واحد.

### Merchant app — short description (EN)

Manage your business, products, offers and subscription in one place.

### Merchant app — full description (AR)

تطبيق دليل أي خدمة - الأعمال مخصص لأصحاب المحلات والخدمات. يمكنك إدارة بيانات النشاط، الموقع، المنتجات، الصور، العروض، التقييمات، الإشعارات والاشتراك، ومتابعة خطوات تجهيز النشاط من داخل التطبيق باستخدام نفس حساب دليل أي خدمة.

### Merchant app — full description (EN)

Daliil Ay Khidma Business is built for merchants and service owners. Manage business information, location, products, images, offers, reviews, notifications and subscriptions, and complete business onboarding using the same Daliil Ay Khidma account.

## Public URLs

Use the production HTTPS URLs below in both stores after verifying deployment:

- Privacy policy: `https://daliil-ay-khidma.onrender.com/privacy/`
- Terms: `https://daliil-ay-khidma.onrender.com/terms/`
- Support: `https://daliil-ay-khidma.onrender.com/support/`
- Account deletion: `https://daliil-ay-khidma.onrender.com/account-deletion/`

## Store media still required

Do not submit to production until final branded assets have been reviewed on real devices.

- 1024×1024 App Store icon for each app.
- Google Play 512×512 icon for each app.
- Google Play feature graphic 1024×500 for each app.
- Phone screenshots in Arabic and English for both apps.
- iPhone screenshots for the App Store device sizes requested by App Store Connect at submission time.
- iPad screenshots only if the final iOS target continues to support iPad.
- Final splash/launch appearance verified on Android and iOS.

## First-release screenshot story

### User app

1. Home / discovery.
2. Search results.
3. Interactive map.
4. Business details.
5. Products / offers.
6. Favorites or notifications.
7. Subscription / onboarding journey where appropriate.

### Merchant app

1. Merchant dashboard.
2. Business profile/editor.
3. Products management.
4. Offers/deals management.
5. Reviews and replies.
6. Subscription center.
7. Settings / onboarding progress.

## Identity and signing rules

- Never change an application ID / bundle ID after the first store release unless creating a new store app.
- Android production builds must use the real Play upload keystore, never the CI key or debug signing.
- iOS production builds must use the correct Apple Team, App ID, distribution certificate and provisioning profile.
- User Firebase config must match the User app IDs exactly.
- Merchant must not reuse the User app Firebase identity. Merchant currently does not depend on Firebase; its stale copied iOS Firebase resource has been neutralized until the Xcode resource reference is removed or a dedicated Merchant Firebase app is intentionally configured.

## Before creating store records

- Confirm the legal/store owner name that should appear publicly.
- Confirm support email and support contact details.
- Confirm final category selections in Google Play and App Store Connect.
- Confirm content rating / age rating answers.
- Re-check `STORE_PRIVACY_DECLARATIONS.md` against the exact release binaries.
- Verify account deletion end-to-end against production.
- Verify production API, push notifications and deep links.

## Release candidate command targets

Android production candidate (after adding real local signing config):

```bash
flutter build appbundle --release --dart-define=API_BASE_URL=https://daliil-ay-khidma.onrender.com
```

iOS candidate before archive signing setup can continue to be smoke-tested with:

```bash
flutter build ios --release --no-codesign --dart-define=API_BASE_URL=https://daliil-ay-khidma.onrender.com
```

The signed `.ipa` must be created only after the Apple Team/App ID/provisioning setup is complete.
